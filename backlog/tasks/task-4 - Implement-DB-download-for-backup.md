---
id: task-4
title: Implement DB download for backup
status: To Do
assignee: []
created_date: "2025-07-08"
labels: []
dependencies: []
priority: medium
---

## Description

For backup purposes I'd like to be able to download the full sqlite db file
(while the app is running). I'm not sure how best to do this:

- somehow through the web app
- via a script (through a `fly console ssh` or something similar) that shells
  into the fly vm directly
