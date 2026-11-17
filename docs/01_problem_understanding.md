# Dream11 problem understanding

On match day a player opens the lobby, picks a team and joins a contest. Once play starts, the score, leaderboard and wallet need to keep up. Finance and operations use the same data to audit money movements, catch rule violations and report on contests.

| Problem | What the stakeholder needs | Workload |
| --- | --- | --- |
| P1 | A fantasy player needs to find the match, eligible players and open contests before team selection closes. | Customer-facing, real-time |
| P2 | A fantasy player needs to pull up saved teams, see the leaderboard and review wallet activity during a match. | Customer-facing, real-time |
| P3 | The contest engine needs to save a team, enter it in a contest and record the entry-fee debit quickly. | Customer-facing, real-time |
| P4 | The fair-play team needs to investigate invalid lineups and users who enter several teams in one contest. | Reporting and analytics |
| P5 | Finance needs an audit that identifies a paid entry with a missing debit, even when other wallet rows lack an entry reference. | Reporting and analytics |
| P6 | Payouts and compliance need to identify pending withdrawals, missing refunds, restricted-state entries and KYC cases. | Reporting and analytics, with interactive handling for payout operations |
| P7 | The points engine needs to update match scores, and the stats team needs to review form and selection data. | Reporting and analytics, with interactive score updates |
| P8 | Product and finance need fill rates, winnings, head-to-head results and deposit totals as the data grows. | Reporting and analytics |

Assumptions. The CSV exports establish the baseline. A missing link or rule violation found in the data is recorded as an audit finding. Money fields use exact decimal amounts, and the date cutoffs embedded in the assigned queries stay fixed for comparison. Writes are run in transactions that roll back after measurement.
