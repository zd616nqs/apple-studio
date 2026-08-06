# DemoPhotoMark 术语表

| 术语 | 含义 |
|---|---|
| Watermark(水印) | 叠加在图片上的文字标记,PMWatermarkRenderer 渲染 |
| Caption(标注文本) | 水印文字,经共享层 LGCStringSanitizer 清洗(去首尾空白、折叠连续空白) |
| RemotePhoto(远程图) | SDWebImage 加载的网络图片,加载中显示 MBProgressHUD |

(正式 app 的 CONTEXT.md 在此维护领域术语 ↔ 代码类型的对照,capability 名与模块名对齐。)
