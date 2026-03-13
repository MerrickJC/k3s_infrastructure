# Sample Weekly Entry

Please **replace the example below** with your own content, following the
same numbered-list style in each of the actual files (`tasks.md`, `progress.md`,
`potential_exploration.md`, `index.md`).

**Example**

1. Task 1  
2. Task 2  
3. Task 3  

---
# Structure

```
├── .gitignore
├── README.md
│
├── weekly_meeting/                   # ← primary source for progress aggregation
│   ├── 2025-04-21/                   # ISO-8601 date: YYYY-MM-DD
│   │   ├── tasks.md                  # ① Task list for the week
│   │   ├── progress.md               # ② Experimental progress / results
│   │   ├── potential_exploration.md  # ③ Key issues & potential explanations
│   │   └── images/                   # ④ Screenshots, plots, etc.
│   ├── 2025-04-28/
│   │   └── …
│   └── index.md                      # Table of potential exploration contents and key milestone for all weeks (move to docs)
│
├── project/                          # Code + datasets
│   ├── code/
│   │   ├── src/                      # Production code
│   │   ├── config/                   # YAML / JSON hyper-params, paths, dependencies (MANDATORY for dependency, including requirements.txt or software versions)
│   │   ├── tests/                    # Unit / integration tests
│   │   └── models/                   # (optional) different model checkpoints, or the models we neee to load from other's work
│   └── dataset/
│       ├── raw/                      # Raw data, the dataset we find from somewhere, like Mnist or Amazon Clothing
│       └── processed/                # Pre-processed data, the dataset we may need to conbine like multi-modal dataset
│
└── docs/                             # Technical docs & deliverables
    ├── uml/
    │   ├── class_diagrams/           # UML class diagrams
    │   └── sequence_diagrams/        # UML sequence diagrams
    ├── guides/                       # How-to guides
    │   └── quick_start.md
    │   └── trick_solving.md          # steps for solving hard problems
    |
    └── results/                      # Figures, tables, paper results

```
