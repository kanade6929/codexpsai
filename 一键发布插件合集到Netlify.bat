@echo off
chcp 65001 >nul
cd /d "%~dp0"
set attempt=1

:upload
echo 正在发布 Codex PS/AI 插件合集（第 %attempt% 次尝试）...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-netlify.ps1"
if not errorlevel 1 goto success

if %attempt% GEQ 3 goto failed
set /a attempt+=1
echo Netlify 上传失败，5 秒后自动重试...
timeout /t 5 /nobreak >nul
goto upload

:success
echo.
echo 发布成功。请打开 netlify-site.config.json 里配置的线上地址查看。
goto end

:failed
echo.
echo 连续三次失败。请查看 upload-log.txt，或手动上传脚本生成的 netlify-backup zip。

:end
echo.
pause
