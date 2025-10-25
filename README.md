# 📸 Wildlife Photo Contest Verifier

A decentralized smart contract for running verified wildlife photography contests on the Stacks blockchain. This contract enables photographers to submit their wildlife photos, allows community voting, and automatically distributes prizes to winners.

## 🌟 Features

- **🏆 Contest Creation**: Create themed wildlife photography contests with custom submission fees and duration
- **📷 Photo Submissions**: Submit wildlife photos with metadata (species, location, description)
- **✅ Photo Verification**: Verification system to ensure photo authenticity
- **🗳️ Community Voting**: Weighted voting system (1-10 points per vote, max 3 votes per user per contest)
- **💰 Automatic Payouts**: 90% to winner, 10% to contest creator
- **🔒 Secure & Transparent**: All transactions recorded on-chain

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- STX tokens for transactions

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/Wildlife-Photo-Contest-Verifier.git
cd Wildlife-Photo-Contest-Verifier
```

2. Check the contract:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

## 📋 Contract Functions

### Public Functions

#### `create-contest`
Create a new wildlife photography contest.
```clarity
(create-contest "Amazing Birds" "Submit your best bird photography" u1440 u1000000)
```
- `title`: Contest title (max 100 characters)
- `description`: Contest description (max 500 characters) 
- `duration-blocks`: Contest duration in blocks
- `submission-fee`: Fee in microSTX

#### `submit-photo`
Submit a photo to a contest.
```clarity
(submit-photo u1 "Eagle in Flight" "Captured at sunset" "hash123..." "Yellowstone Park" "Bald Eagle")
```
- `contest-id`: Contest identifier
- `title`: Photo title
- `description`: Photo description
- `image-hash`: IPFS hash or similar
- `location`: Where photo was taken
- `species`: Wildlife species captured

#### `vote-for-photo`
Vote for a submitted photo (after contest ends).
```clarity
(vote-for-photo u5 u8)
```
- `photo-id`: Photo to vote for
- `vote-weight`: Vote strength (1-10)

#### `verify-photo`
Verify a photo's authenticity (photographer or contract owner only).
```clarity
(verify-photo u5)
```

#### `finalize-contest`
Finalize contest and distribute prizes (after voting period).
```clarity
(finalize-contest u1 u5)
```
- `contest-id`: Contest to finalize
- `winner-photo-id`: Winning photo ID

### Read-Only Functions

#### `get-contest`
Get contest details.
```clarity
(get-contest u1)
```

#### `get-photo`
Get photo submission details.
```clarity
(get-photo u5)
```

#### `get-contest-winner`
Get the winner of a finalized contest.
```clarity
(get-contest-winner u1)
```

#### `has-user-submitted`
Check if user has submitted to contest.
```clarity
(has-user-submitted u1 'SP1234...)
```

#### `is-photo-verified`
Check if photo is verified.
```clarity
(is-photo-verified u5)
```

## 🎯 Usage Flow

1. **Create Contest**: Contest creator sets up a new contest with parameters
2. **Submit Photos**: Photographers submit entries with required metadata and fee
3. **Verify Photos**: Photos get verified for authenticity
4. **Voting Period**: Community votes on verified photos after contest ends
5. **Finalization**: Winner is determined and prizes are distributed automatically

## ⚖️ Contest Rules

- 📸 One submission per user per contest
- ✅ Photos must be verified to be eligible for winning
- 🗳️ Voting opens after contest submission period ends
- 🏆 Only verified photos can win
- 💰 Prize distribution: 90% winner, 10% contest creator
- ⏰ Contest finalization available 144 blocks after voting starts

## 🔧 Error Codes

- `u100`: Owner only operation
- `u101`: Not found
- `u102`: Unauthorized
- `u103`: Invalid submission
- `u104`: Contest ended
- `u105`: Contest not ended
- `u106`: Already voted
- `u107`: Invalid vote
- `u108`: Contest not found
- `u109`: Already submitted

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🐛 Issues & Support

If you encounter any issues or need support, please open an issue on GitHub.

---

*Built with ❤️ for wildlife photography enthusiasts on Stacks blockchain*
