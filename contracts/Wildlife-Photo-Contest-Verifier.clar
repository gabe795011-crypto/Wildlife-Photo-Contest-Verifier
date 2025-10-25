(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-submission (err u103))
(define-constant err-contest-ended (err u104))
(define-constant err-contest-not-ended (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-invalid-vote (err u107))
(define-constant err-contest-not-found (err u108))
(define-constant err-already-submitted (err u109))

(define-data-var next-contest-id uint u1)
(define-data-var next-photo-id uint u1)

(define-map contests
  { contest-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    start-block: uint,
    end-block: uint,
    submission-fee: uint,
    prize-pool: uint,
    total-submissions: uint,
    winner-photo-id: (optional uint),
    is-finalized: bool
  }
)

(define-map photo-submissions
  { photo-id: uint }
  {
    contest-id: uint,
    photographer: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    image-hash: (string-ascii 64),
    location: (string-ascii 100),
    species: (string-ascii 50),
    submission-block: uint,
    vote-count: uint,
    verified: bool
  }
)

(define-map contest-participants
  { contest-id: uint, participant: principal }
  { submitted: bool }
)

(define-map photo-votes
  { photo-id: uint, voter: principal }
  { vote-weight: uint }
)

(define-map user-contest-votes
  { contest-id: uint, voter: principal }
  { votes-cast: uint }
)

(define-map contest-photos
  { contest-id: uint, photo-id: uint }
  { exists: bool }
)

(define-map contest-winner-cache
  { contest-id: uint }
  { winner-photo-id: uint, cached-at-block: uint }
)

(define-public (create-contest (title (string-ascii 100)) (description (string-ascii 500)) (duration-blocks uint) (submission-fee uint))
  (let
    (
      (contest-id (var-get next-contest-id))
      (start-block stacks-block-height)
      (end-block (+ stacks-block-height duration-blocks))
    )
    (asserts! (> duration-blocks u0) err-invalid-submission)
    (map-set contests
      { contest-id: contest-id }
      {
        title: title,
        description: description,
        creator: tx-sender,
        start-block: start-block,
        end-block: end-block,
        submission-fee: submission-fee,
        prize-pool: u0,
        total-submissions: u0,
        winner-photo-id: none,
        is-finalized: false
      }
    )
    (var-set next-contest-id (+ contest-id u1))
    (ok contest-id)
  )
)

(define-public (submit-photo (contest-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (image-hash (string-ascii 64)) (location (string-ascii 100)) (species (string-ascii 50)))
  (let
    (
      (contest (unwrap! (map-get? contests { contest-id: contest-id }) err-contest-not-found))
      (photo-id (var-get next-photo-id))
      (participant-key { contest-id: contest-id, participant: tx-sender })
    )
    (asserts! (< stacks-block-height (get end-block contest)) err-contest-ended)
    (asserts! (is-none (map-get? contest-participants participant-key)) err-already-submitted)
    (try! (stx-transfer? (get submission-fee contest) tx-sender (as-contract tx-sender)))
    (map-set photo-submissions
      { photo-id: photo-id }
      {
        contest-id: contest-id,
        photographer: tx-sender,
        title: title,
        description: description,
        image-hash: image-hash,
        location: location,
        species: species,
        submission-block: stacks-block-height,
        vote-count: u0,
        verified: false
      }
    )
    (map-set contest-participants participant-key { submitted: true })
    (map-set contest-photos { contest-id: contest-id, photo-id: photo-id } { exists: true })
    (map-set contests
      { contest-id: contest-id }
      (merge contest { 
        total-submissions: (+ (get total-submissions contest) u1),
        prize-pool: (+ (get prize-pool contest) (get submission-fee contest))
      })
    )
    (var-set next-photo-id (+ photo-id u1))
    (ok photo-id)
  )
)

(define-public (vote-for-photo (photo-id uint) (vote-weight uint))
  (let
    (
      (photo (unwrap! (map-get? photo-submissions { photo-id: photo-id }) err-not-found))
      (contest (unwrap! (map-get? contests { contest-id: (get contest-id photo) }) err-contest-not-found))
      (voter-key { photo-id: photo-id, voter: tx-sender })
      (user-votes-key { contest-id: (get contest-id photo), voter: tx-sender })
      (current-user-votes (default-to { votes-cast: u0 } (map-get? user-contest-votes user-votes-key)))
    )
    (asserts! (>= stacks-block-height (get end-block contest)) err-contest-not-ended)
    (asserts! (not (get is-finalized contest)) err-contest-ended)
    (asserts! (is-none (map-get? photo-votes voter-key)) err-already-voted)
    (asserts! (and (> vote-weight u0) (<= vote-weight u10)) err-invalid-vote)
    (asserts! (< (get votes-cast current-user-votes) u3) err-invalid-vote)
    (map-set photo-votes voter-key { vote-weight: vote-weight })
    (map-set user-contest-votes user-votes-key { votes-cast: (+ (get votes-cast current-user-votes) u1) })
    (map-set photo-submissions
      { photo-id: photo-id }
      (merge photo { vote-count: (+ (get vote-count photo) vote-weight) })
    )
    (ok true)
  )
)

(define-public (verify-photo (photo-id uint))
  (let
    (
      (photo (unwrap! (map-get? photo-submissions { photo-id: photo-id }) err-not-found))
    )
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get photographer photo))) err-unauthorized)
    (map-set photo-submissions
      { photo-id: photo-id }
      (merge photo { verified: true })
    )
    (ok true)
  )
)

(define-public (finalize-contest (contest-id uint) (winner-photo-id uint))
  (let
    (
      (contest (unwrap! (map-get? contests { contest-id: contest-id }) err-contest-not-found))
      (winner-photo (unwrap! (map-get? photo-submissions { photo-id: winner-photo-id }) err-not-found))
      (prize-amount (/ (* (get prize-pool contest) u90) u100))
      (creator-fee (- (get prize-pool contest) prize-amount))
    )
    (asserts! (is-eq (get contest-id winner-photo) contest-id) err-invalid-submission)
    (asserts! (get verified winner-photo) err-invalid-submission)
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get creator contest))) err-unauthorized)
    (asserts! (>= stacks-block-height (+ (get end-block contest) u144)) err-contest-not-ended)
    (asserts! (not (get is-finalized contest)) err-contest-ended)
    (try! (as-contract (stx-transfer? prize-amount tx-sender (get photographer winner-photo))))
    (try! (as-contract (stx-transfer? creator-fee tx-sender (get creator contest))))
    (map-set contests
      { contest-id: contest-id }
      (merge contest {
        winner-photo-id: (some winner-photo-id),
        is-finalized: true
      })
    )
    (ok winner-photo-id)
  )
)

(define-read-only (get-contest (contest-id uint))
  (map-get? contests { contest-id: contest-id })
)

(define-read-only (get-photo (photo-id uint))
  (map-get? photo-submissions { photo-id: photo-id })
)

(define-read-only (get-contest-winner (contest-id uint))
  (match (map-get? contests { contest-id: contest-id })
    contest (get winner-photo-id contest)
    none
  )
)

(define-read-only (get-highest-voted-photo (contest-id uint) (photo-id-1 uint) (photo-id-2 uint) (photo-id-3 uint))
  (let
    (
      (photo1 (map-get? photo-submissions { photo-id: photo-id-1 }))
      (photo2 (map-get? photo-submissions { photo-id: photo-id-2 }))
      (photo3 (map-get? photo-submissions { photo-id: photo-id-3 }))
      (votes1 (if (and (is-some photo1) (get verified (unwrap-panic photo1)) (is-eq (get contest-id (unwrap-panic photo1)) contest-id)) (get vote-count (unwrap-panic photo1)) u0))
      (votes2 (if (and (is-some photo2) (get verified (unwrap-panic photo2)) (is-eq (get contest-id (unwrap-panic photo2)) contest-id)) (get vote-count (unwrap-panic photo2)) u0))
      (votes3 (if (and (is-some photo3) (get verified (unwrap-panic photo3)) (is-eq (get contest-id (unwrap-panic photo3)) contest-id)) (get vote-count (unwrap-panic photo3)) u0))
    )
    (if (and (>= votes1 votes2) (>= votes1 votes3))
      (some photo-id-1)
      (if (>= votes2 votes3)
        (some photo-id-2)
        (some photo-id-3)
      )
    )
  )
)

(define-read-only (has-user-submitted (contest-id uint) (user principal))
  (is-some (map-get? contest-participants { contest-id: contest-id, participant: user }))
)

(define-read-only (get-photo-vote (photo-id uint) (voter principal))
  (map-get? photo-votes { photo-id: photo-id, voter: voter })
)

(define-read-only (get-user-votes-in-contest (contest-id uint) (voter principal))
  (default-to { votes-cast: u0 } (map-get? user-contest-votes { contest-id: contest-id, voter: voter }))
)

(define-read-only (is-photo-verified (photo-id uint))
  (match (map-get? photo-submissions { photo-id: photo-id })
    photo (get verified photo)
    false
  )
)

