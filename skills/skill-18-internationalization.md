# Skill-18: 国际化规范

## 前置依赖
skill-00, skill-08

## 目标
定义中英文双语支持的字符串资源、语言切换、日期格式化的完整规范。

---

## 1. 支持语言

| 语言代码 | 语言 | 资源目录 |
|---------|------|---------|
| zh | 中文（简体） | 默认目录（values/） |
| en | English | values-en/ |

**默认语言**：中文（简体）

---

## 2. 字符串资源规范

### 2.1 禁止硬编码的场景

所有用户可见的文本必须使用字符串资源，包括但不限于：

| 场景 | 说明 |
|------|------|
| 页面标题 | 所有 TopAppBar 标题 |
| 按钮文字 | 所有按钮标签 |
| 菜单项 | 所有菜单和下拉选项 |
| 过滤器标签 | FilterChip 文字 |
| 空状态消息 | 所有空状态的主提示和副提示 |
| 对话框文本 | 确认/取消按钮、标题、内容 |
| Toast 消息 | 所有 Toast 提示 |
| 错误提示 | 所有错误信息 |
| 设置项标签 | 设置页面所有文字 |
| 底部导航标签 | Tab 标签文字 |
| 字段标签 | 详情页信息面板字段名 |

### 2.2 字符串资源命名规范

| 类别 | 命名格式 | 示例 |
|------|---------|------|
| 页面标题 | title_{page} | title_home, title_settings |
| 按钮 | btn_{action} | btn_save, btn_cancel, btn_confirm |
| 标签 | label_{name} | label_all, label_image, label_video |
| 消息 | msg_{context} | msg_no_media, msg_import_success |
| 对话框标题 | dialog_{context} | dialog_delete_confirm |
| 对话框内容 | dialog_msg_{context} | dialog_msg_delete_media |
| 菜单项 | menu_{action} | menu_share, menu_delete |
| 设置项 | settings_{key} | settings_theme_mode |
| Tab | tab_{name} | tab_all_media, tab_album, tab_tag |
| 字段 | field_{name} | field_type, field_size, field_dimension |

---

## 3. 语言切换行为

| 设置值 | 行为 |
|--------|------|
| SYSTEM | 读取系统 Locale，匹配 zh 用中文，其他用英文 |
| ZH | 强制使用中文资源 |
| EN | 强制使用英文资源 |

### 3.1 切换流程

1. 用户在设置页更改语言
2. 持久化语言设置
3. 重建当前 Activity 使新语言生效
4. 显示 Toast："语言设置已更改"

### 3.2 Locale 覆盖

| 设置值 | Locale |
|--------|--------|
| SYSTEM | 不覆盖，使用系统默认 |
| ZH | Locale("zh") |
| EN | Locale("en") |

---

## 4. 日期时间格式化

| 场景 | 中文格式 | 英文格式 |
|------|---------|---------|
| 导入时间（完整） | yyyy年MM月dd日 HH:mm | MMM dd, yyyy HH:mm |
| 笔记更新时间 | yyyy-MM-dd HH:mm | MMM dd, yyyy HH:mm |
| 搜索结果日期 | yyyy-MM-dd | MMM dd, yyyy |
| 视频时长 | mm:ss | mm:ss |

### 4.1 文件大小格式化

| 范围 | 中文 | 英文 |
|------|------|------|
| < 1 KB | {n} B | {n} B |
| < 1 MB | {n} KB | {n} KB |
| < 1 GB | {n} MB | {n} MB |
| ≥ 1 GB | {n} GB | {n} GB |

---

## 5. 复数处理

| 场景 | 中文 | 英文 |
|------|------|------|
| 媒体数量 | {count} 个媒体 | {count} media (plural handling) |
| 相册媒体数 | {count} 个媒体 | {count} media |
| 笔记数量 | {count} 条笔记 | {count} notes |
| 选中数量 | 已选中 {count} 项 | {count} selected |

---

## 6. 数字格式化

| 场景 | 格式 |
|------|------|
| 像素尺寸 | 使用系统默认数字格式（不使用千位分隔符） |
| 网格列数 | 纯数字 |
| 进度百分比 | {n}% |

---

## 7. 验证标准

完成本 skill 后，必须满足以下全部条件：

- [ ] 所有用户可见文本已提取到字符串资源
- [ ] 中文和英文资源文件完整且一致
- [ ] 无硬编码字符串（UI 层）
- [ ] 语言切换正确生效
- [ ] 跟随系统语言正确工作
- [ ] 日期时间格式正确
- [ ] 文件大小格式正确
- [ ] 复数形式正确
- [ ] 设置页语言选项正确显示三种选项
