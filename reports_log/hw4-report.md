# HW4 Report

## 1. What Changed and Why

| Change | Reason | Spec Section |
|--------|---------|--------------|
| Add essential testing and clean up code | Since our goal is to create a professional, open-source-ready repository, we need to ensure that essential testing is done and code is clean for other developers. Essential and mandatory tests also ensure that developers' commit won't break existing functionalities | 20-target-spec Phase 1 |
| Add basic health checks and improve security | Basic health checks and improvement in security is important to ensure maintainability as well as data security (prevent XSS vulnerabilities) | 20-target-spec Phase 2 |

## 2. Challenges and Resolutions

When I used Github Copilot (Claude Sonnet 4) to generate code and specs, I realise that AI assistant tend to generate content that is overly ambitious and complex. To solve this, I have learnt to refine my prompt such as by asking Copilot to generate the minimal basic set of requirements before slowly scaling it up. This would ensure that the app development is realistic and achievable.

I also faced issues like duplicate generated content as they seem to have localized memory (search in specific directory). I resolve this by fact checking and reading through the AI generated content to ensure that my code base is clean.


## 3. How to Reproduce Results Locally

1. **Clone the repository**:
   ```bash
   git clone https://github.com/TY1Fan/Name-Manager.git
   cd Name-Manager
   ```

2. **Set up environment** (optional - defaults work for development):
   ```bash
   cd src
   cp .env.example .env
   # Edit .env if you need custom configuration
   ```

3. **Start the application**:
   ```bash
   docker compose up -d
   ```

4. **Access the application**:
   - **Web Interface**: http://localhost:8080