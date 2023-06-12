# Contribute

## Git Workflow

Priciple: One feature, one PR.

1. Make a fork
2. Make a new feature branch based on your master branch: `git checkout master`, `git checkout -b feature-xxx`
3. After finishing new features, add and commit them: `git add .`, `git commit -m <commit_msg>`
4. Before merging into master, you should make sure your changes are based on upstream/master: `git checkout master`, `git fetch upstream master`
5. Then switch to feature-xxx，rebase to master: `git checkout feature-xxx`, `git rebase master`
6. If there are conflicts, please resolve then: `git add <conflict_file>`, `git rebase --continue`
7. Submit your changes: `git push origin feature-xxx`
8. Make a PR at github, after it is successfully merged, delete this feature branch: `git checkout master`, `git branch -d feature-xxx`, `git fetch upstream master`
