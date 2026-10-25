# 積木小宇宙 My Blocks

Godot 4.5.2 / GDScript 的 Android 3D 兒童積木遊戲（4～8 歲）。

## v0.1 已實作
- 30 種方形積木尺寸、32 種顏色與立體凸點。
- 3D 自由放置、格點吸附、旋轉、堆疊、支撐與碰撞檢查。
- 選取、移動、改色、刪除、復原、重做。
- 三個引導作品：房子、車子、高塔。
- 自動存檔與備援、作品收藏館、橫向畫面、離線遊玩。
- 積木小世界為尚未開發的後續功能。

## Release / Signing
工作流程使用本 Repository GitHub Actions Secrets：
KEYSTORE_BASE64、KEYSTORE_PASSWORD、KEY_ALIAS、KEY_PASSWORD。
此命名與 farm 專案相同，私鑰不會提交進 Git。
其他 Repository 的 Secrets 不會自動共享，請確認 my-blocks 確實設定了相同的既有 key。
沒有 key 時 CI 會失敗，絕不另外產生不相容的新私鑰。
只有測試、簽章和 APK 憑證驗證成功後，才發布新版 Release 並清除舊 Release。
APK：https://github.com/jimmy0933b3-sudo/my-blocks/releases/latest

本機以 Godot 4.5.2 開啟 project.godot。
