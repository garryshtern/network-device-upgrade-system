# Code Analysis & Quality Report

Perform a comprehensive code analysis covering best practices, error detection, and requirements validation.

## Analysis Tasks

### 1. CODE QUALITY ANALYSIS
- Review all source code files for best practices specific to the language(s) used
- Check for code smells, anti-patterns, and maintainability issues
- Evaluate code organization, modularity, and separation of concerns
- Assess naming conventions, documentation, and code clarity
- Identify opportunities for refactoring or optimization

### 2. ERROR DETECTION
- Look for masked or silently handled errors (empty catch blocks, ignored exceptions)
- Identify potential runtime errors (null references, boundary conditions, race conditions)
- Check for missing error handling and edge cases
- Review logging practices and error reporting
- Find security vulnerabilities or unsafe practices

### 3. REQUIREMENTS VALIDATION
- Read and parse the requirements document (check for requirements.md, README.md, docs/requirements.txt, or similar)
- Cross-reference each requirement against the implementation
- Identify missing features or incomplete implementations
- Note any deviations from specified requirements
- Flag requirements that are ambiguous or need clarification

### 4. SCORING SYSTEM
Generate a comprehensive score (0-100) based on:
- **Code Quality**: 30 points
- **Error Handling & Robustness**: 25 points
- **Requirements Completeness**: 30 points
- **Documentation & Maintainability**: 15 points

Provide subscores for each category with clear justification.

### 5. IMPROVEMENT TODO PLAN
Create a prioritized action plan organized by severity:

**CRITICAL** - Must fix immediately
**HIGH** - Important improvements
**MEDIUM** - Recommended enhancements
**LOW** - Nice-to-have suggestions

For each item include:
- Specific file paths and line numbers
- Clear description of the issue
- Recommended solution or approach
- Estimated effort (S/M/L)

## Output Format

Provide the analysis as a structured markdown report with:
- Executive summary with overall score
- Detailed findings for each category
- Specific code examples with file references
- Prioritized TODO list with actionable items
- Recommendations for immediate next steps