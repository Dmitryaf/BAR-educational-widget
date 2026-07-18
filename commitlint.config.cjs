module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "body-max-line-length": [2, "always", 100],
    "footer-max-line-length": [2, "always", 100],
    "header-max-length": [2, "always", 72],
    "scope-enum": [
      2,
      "always",
      [
        "app",
        "architecture",
        "config",
        "docs",
        "domain",
        "infra",
        "research",
        "tasks",
        "tests",
        "tooling",
        "ui"
      ]
    ],
    "type-enum": [
      2,
      "always",
      [
        "build",
        "chore",
        "ci",
        "docs",
        "feat",
        "fix",
        "perf",
        "refactor",
        "revert",
        "style",
        "test"
      ]
    ]
  }
};
