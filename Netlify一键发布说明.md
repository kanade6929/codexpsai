# Netlify 傻瓜式发布说明

## 第一次发布

1. 双击 `01_打开NetlifyToken页面.bat`。
2. Chrome 会打开 Netlify 的 token 页面。
3. 如果还没登录，先登录 Netlify。
4. 在页面里点 `New access token`。
5. 名字随便填，例如 `codex-adobe-tools`。
6. 点生成后，复制那一长串 token。注意：这个 token 通常只显示一次。
7. 回到本文件夹，双击 `03_正式上传到Netlify.bat`。
8. 窗口提示 `Netlify token` 时，把刚才那串 token 粘贴进去，回车。
9. 它问是否保存 token 时，输入 `y`，以后就不用再填。

## 每次更新后发布

以后只需要双击：

`03_正式上传到Netlify.bat`

脚本会自动：

1. 重新整理插件文件夹。
2. 更新 `plugins.json`。
3. 生成 Netlify 上传包。
4. 上传到你的 Netlify 站点。

## 只检查不上传

双击：

`02_先检查不上传.bat`

这个只会检查和生成备份包，不会真的上传。

## Site ID 在哪里

Netlify 进入你的站点后：

`Site configuration` > `General` > `Site details` > `Site ID`

复制后填到 `netlify-site.config.json` 里的 `siteId`。

`siteUrl` 填你的站点网址，例如：

```json
{
  "siteId": "你的 Site ID",
  "siteUrl": "https://你的站点.netlify.app/",
  "siteName": "codex-adobe-tools"
}
```

## 如果你不想用 token

可以把最新的 `codex-adobe-tools-netlify-backup-*.zip` 手动拖到 Netlify 的手动部署页面。
