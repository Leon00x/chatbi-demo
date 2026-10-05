# Lion City ChatBI

A hands-on project for continuing ChatBI development with Huawei Cloud CodeArts Agent. Ask questions in English or Chinese; Huawei Cloud MaaS generates SQL, the backend checks and runs a read-only query, and the app displays the results.

The included scenario is a fictional Singapore retailer with four stores and eight products. All data is synthetic, covers January–September 2026 and uses SGD.

## Current version

The `main` branch is the starter: query chat, result tables, expandable SQL, optional analysis through the **Include business analysis** checkbox, connection checks and English/Chinese switching. **New chat** clears the current conversation. English is the default language.

Default charts, question-based analysis, model selection and saved conversations are development tasks. Conversations currently disappear on refresh or New chat.

## Get started

Use compatible Python 3.11+ and Node.js 20+ installations with npm. Follow [Step 0 in the guide](guide.md#step-0-prepare-the-environment-configure-maas-then-start-manually) to prepare the environment, configure your MaaS token, and start both services.

The default app address is [http://127.0.0.1:5173/](http://127.0.0.1:5173/). Use Vite's printed address if you change the port. Once connected, select a suggested question on the page or type your own.

Continue with [the development tasks](guide.md#step-1-show-charts-by-default-and-analyze-when-asked), either yourself or with the optional CodeArts Agent prompts. Start with Step 1 to add default charts and question-based analysis.

## Documentation

| Document | When to read it |
|---|---|
| [guide.md](guide.md) | Set up, run the demo and continue development |
| [docs/architecture.md](docs/architecture.md) | Understand the components and query flow |
| [docs/api.md](docs/api.md) | Change or call the backend API |
| [docs/data-dictionary.md](docs/data-dictionary.md) | Understand the sample data and metrics |
| [AGENTS.md](AGENTS.md) | Development instructions and checks for coding agents |

## Project structure

```text
backend/app/        FastAPI API, MaaS client and SQL safety
backend/scenarios/  Scenario description and seed configuration
backend/data/       Synthetic SQLite database
backend/tests/      Backend and SQL safety tests
frontend/src/       React + TypeScript conversation UI
docs/               Architecture, API and data dictionary
setup.ps1           Windows environment setup
setup.sh            Linux / macOS environment setup
```

The app uses Vite, Tailwind CSS and SQLAlchemy alongside the components above. It is a local demo with SQLite, without login or tenant isolation. MaaS credentials stay in the backend; real model requests consume your account quota.
