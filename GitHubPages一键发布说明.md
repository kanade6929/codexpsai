# GitHub Pages 一键发布说明

## 第一次发布

1. 打开 GitHub，创建一个新的空仓库。
2. 仓库名建议用 `codex-adobe-tools`。
3. 不要勾选 README、.gitignore 或 license，保持空仓库。
4. 复制仓库 HTTPS 地址，例如：
   `https://github.com/你的用户名/codex-adobe-tools.git`
5. 回到本文件夹，双击：
   `一键发布插件合集到GitHubPages.bat`
6. 第一次运行时，把仓库 HTTPS 地址粘贴进去。
7. 如果 Git 弹出 GitHub 登录窗口，按提示登录授权。
8. 如果 GitHub 没有自动打开 Pages，在仓库里进入 `Settings > Pages`，选择 `Deploy from a branch`，分支选 `gh-pages`，目录选 `/ (root)`。

## 以后更新

以后只需要更新插件源文件，然后双击：

`03_正式发布到GitHubPages.bat`

脚本会自动：

1. 重新打包每个插件 ZIP。
2. 更新 `plugins.json`。
3. 提交到本地 git。
4. 推送到 GitHub。
5. 触发 GitHub Pages 自动上线。

## 检查但不上传

运行：

`02_GitHub先检查不上传.bat`

它会打包和检查，但不会推送到 GitHub。

## 线上地址

如果仓库名是 `codex-adobe-tools`，发布后通常是：

`https://你的用户名.github.io/codex-adobe-tools/`

如果你以后绑定自己的域名，可以在 GitHub 仓库的 Pages 设置里添加自定义域名。
