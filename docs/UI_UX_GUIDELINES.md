# UI/UX Design Guidelines

## Document Information

| Property | Value |
|----------|-------|
| **Version** | 1.0.0 |
| **Last Updated** | 2026-05-19 |
| **Status** | Active |
| **Design System** | Material 3 Extended |

---

## 1. Design Philosophy

### 1.1 Core Principles

| Principle | Description |
|-----------|-------------|
| **简洁至上** | 减少认知负担，核心功能一目了然 |
| **信任感** | 通过设计传达安全、可靠、专业 |
| **一致性** | 跨平台统一体验，降低学习成本 |
| **可访问性** | 所有人都能使用，包括残障人士 |
| **本地化** | 中文优先，符合中国用户习惯 |

### 1.2 Design Values

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      DESIGN VALUES                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                   │
│  │   隐私      │   │   简洁      │   │   专业      │                   │
│  │   Privacy   │   │  Simplicity │   │ Professional│                   │
│  └─────────────┘   └─────────────┘   └─────────────┘                   │
│                                                                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                   │
│  │   可靠      │   │   友好      │   │   高效      │                   │
│  │ Reliability │   │ Friendliness│   │  Efficiency │                   │
│  └─────────────┘   └─────────────┘   └─────────────┘                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Color System

### 2.1 Primary Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Primary** | `#2196F3` | 主要按钮、选中状态、品牌色 |
| **Primary Dark** | `#1976D2` | 按钮悬停、强调状态 |
| **Primary Light** | `#BBDEFB` | 背景、卡片高亮 |

### 2.2 Semantic Colors

| Color | Hex | Usage | Chinese Context |
|-------|-----|-------|-----------------|
| **Income** | `#4CAF50` | 收入、正向变化 | 中国传统：红色代表收入 |
| **Expense** | `#F44336` | 支出、负向变化 | 中国传统：绿色代表支出 |
| **Warning** | `#FF9800` | 预算警告、提醒 | 中性警示 |
| **Success** | `#4CAF50` | 操作成功、确认 | 正向反馈 |
| **Error** | `#B00020` | 错误、危险操作 | 负向反馈 |

### 2.3 Chinese Market Adaptation

```
┌─────────────────────────────────────────────────────────────────────────┐
│              CHINESE FINTECH COLOR CONVENTIONS                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  收入 (Income)                                                           │
│  ├── 传统：红色 (+¥100.00)                                              │
│  ├── 现代：绿色 (+¥100.00)                                              │
│  └── 本应用：绿色 (国际标准，避免与"赤字"混淆)                          │
│                                                                          │
│  支出 (Expense)                                                          │
│  ├── 传统：绿色 (-¥100.00)                                              │
│  ├── 现代：红色 (-¥100.00)                                              │
│  └── 本应用：红色 (国际标准，直观警示)                                   │
│                                                                          │
│  ⚠️ 重要：应用内提供设置选项，用户可选择传统/现代配色                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Dark Mode Colors

| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| **Background** | `#FAFAFA` | `#121212` |
| **Surface** | `#FFFFFF` | `#1E1E1E` |
| **Card** | `#FFFFFF` | `#2C2C2C` |
| **Text Primary** | `#212121` | `#FFFFFF` |
| **Text Secondary** | `#757575` | `#B0B0B0` |
| **Divider** | `#E0E0E0` | `#424242` |

---

## 3. Typography

### 3.1 Font Family

| Platform | Primary Font | Fallback |
|----------|--------------|----------|
| **iOS** | PingFang SC | SF Pro |
| **Android** | Noto Sans SC | Roboto |
| **Web** | Noto Sans SC | system-ui |
| **Desktop** | Noto Sans SC | Segoe UI |

### 3.2 Type Scale

| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| **Display Large** | 57sp | Bold | 64sp | 大数字（余额） |
| **Display Medium** | 45sp | Bold | 52sp | 页面标题 |
| **Display Small** | 36sp | Bold | 44sp | 卡片标题 |
| **Headline Large** | 32sp | Medium | 40sp | 区块标题 |
| **Headline Medium** | 28sp | Medium | 36sp | 列表标题 |
| **Headline Small** | 24sp | Medium | 32sp | 小标题 |
| **Title Large** | 22sp | Medium | 28sp | 顶部AppBar |
| **Title Medium** | 16sp | Medium | 24sp | 列表项标题 |
| **Title Small** | 14sp | Medium | 20sp | 小组件标题 |
| **Body Large** | 16sp | Regular | 24sp | 正文内容 |
| **Body Medium** | 14sp | Regular | 20sp | 次要内容 |
| **Body Small** | 12sp | Regular | 16sp | 辅助信息 |
| **Label Large** | 14sp | Medium | 20sp | 按钮文字 |
| **Label Medium** | 12sp | Medium | 16sp | 标签 |
| **Label Small** | 11sp | Medium | 16sp | 小标签 |

### 3.3 Number Formatting

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    NUMBER DISPLAY RULES                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  金额显示                                                                │
│  ├── 正数：+¥1,234.56 (绿色)                                           │
│  ├── 负数：-¥1,234.56 (红色)                                           │
│  ├── 零：¥0.00 (灰色)                                                  │
│  └── 大额：¥12,345.67 或 ¥1.23万 (可设置)                              │
│                                                                          │
│  千分位分隔                                                              │
│  ├── 中文：¥1,234.56                                                   │
│  └── 国际：¥1.234,56 (可选)                                             │
│                                                                          │
│  货币符号位置                                                            │
│  ├── 默认：符号在前 ¥100                                                │
│  └── 可选：符号在后 100元                                               │
│                                                                          │
│  日期格式                                                                │
│  ├── 默认：2026年5月19日                                                │
│  ├── 简短：5月19日                                                      │
│  └── 相对：今天、昨天、3天前                                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Spacing & Layout

### 4.1 Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| **xs** | 4dp | 图标与文字间距 |
| **sm** | 8dp | 紧凑元素间距 |
| **md** | 16dp | 标准内边距 |
| **lg** | 24dp | 卡片间距 |
| **xl** | 32dp | 区块间距 |
| **2xl** | 48dp | 页面区块间距 |

### 4.2 Grid System

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GRID SYSTEM                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Mobile (< 600dp)                                                       │
│  ├── Columns: 4                                                         │
│  ├── Margin: 16dp                                                       │
│  └── Gutter: 16dp                                                       │
│                                                                          │
│  Tablet (600dp - 840dp)                                                 │
│  ├── Columns: 8                                                         │
│  ├── Margin: 24dp                                                       │
│  └── Gutter: 24dp                                                       │
│                                                                          │
│  Desktop (> 840dp)                                                      │
│  ├── Columns: 12                                                        │
│  ├── Margin: 32dp                                                       │
│  └── Gutter: 24dp                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Component Spacing

| Component | Padding | Margin |
|-----------|---------|--------|
| **Card** | 16dp | 8dp (bottom) |
| **List Item** | 16dp horizontal | 0dp |
| **Button** | 24dp horizontal, 12dp vertical | 8dp |
| **Input Field** | 16dp | 16dp (bottom) |
| **Section Header** | 16dp | 24dp (top), 8dp (bottom) |

---

## 5. Components

### 5.1 Buttons

#### Primary Button

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                     Primary Button                               │   │
│  │                                                                 │   │
│  │  Height: 48dp                                                   │   │
│  │  Padding: 24dp horizontal                                       │   │
│  │  Corner Radius: 8dp                                             │   │
│  │  Background: Primary (#2196F3)                                  │   │
│  │  Text: White, 14sp, Medium                                      │   │
│  │  Elevation: 0dp (flat) or 2dp (raised)                         │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  States:                                                                 │
│  ├── Normal: Primary color                                              │
│  ├── Hover: Primary Dark                                               │
│  ├── Pressed: Primary Dark + 0.12 overlay                              │
│  ├── Disabled: Gray (#9E9E9E) + 0.38 opacity                           │
│  └── Focus: 2dp outline                                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Secondary Button

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                   Secondary Button                               │   │
│  │                                                                 │   │
│  │  Height: 48dp                                                   │   │
│  │  Padding: 24dp horizontal                                       │   │
│  │  Corner Radius: 8dp                                             │   │
│  │  Background: Surface Container High                             │   │
│  │  Text: Primary, 14sp, Medium                                    │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### FAB (Floating Action Button)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│      ┌─────────────┐                                                    │
│      │      +      │  FAB                                               │
│      │             │                                                    │
│      └─────────────┘                                                    │
│                                                                          │
│  Size: 56dp x 56dp                                                      │
│  Icon: 24dp                                                             │
│  Corner Radius: 16dp                                                    │
│  Background: Primary Container                                          │
│  Elevation: 6dp                                                         │
│  Shadow: Standard                                                       │
│                                                                          │
│  Extended FAB:                                                           │
│  ┌─────────────────────────────────┐                                    │
│  │  +  记一笔                      │                                    │
│  └─────────────────────────────────┘                                    │
│  Height: 48dp                                                           │
│  Padding: 16dp start, 20dp end                                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Cards

#### Standard Card

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                 │   │
│  │  Card Title                                                     │   │
│  │  ─────────────────────────────────────────────                  │   │
│  │                                                                 │   │
│  │  Card content goes here. This is the body text.                │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Corner Radius: 12dp                                                    │
│  Elevation: 2dp                                                         │
│  Padding: 20dp                                                          │
│  Background: Surface                                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Transaction Card

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ┌──────┐                                                       │   │
│  │  │ 🍔  │  餐饮美食                    -¥35.50          🗑️    │   │
│  │  └──────┘  美团外卖                                        │   │
│  │             10:30                                         │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Layout:                                                                 │
│  ├── Icon: 48dp x 48dp, rounded 12dp                                    │
│  ├── Title: 16sp, Medium                                                │
│  ├── Subtitle: 14sp, Regular, Secondary color                           │
│  ├── Amount: 16sp, Bold, Income/Expense color                           │
│  └── Time: 12sp, Regular, Secondary color                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Input Fields

#### Text Input

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 金额                                                            │   │
│  │ ┌───────────────────────────────────────────────────────────┐  │   │
│  │ │ ¥ 35.50                                                   │  │   │
│  │ └───────────────────────────────────────────────────────────┘  │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Height: 56dp                                                           │
│  Corner Radius: 8dp                                                     │
│  Padding: 16dp                                                          │
│  Background: Surface Container Highest                                  │
│  Border: None (filled style)                                            │
│  Focus Border: 2dp, Primary color                                       │
│  Error Border: 1dp, Error color                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Navigation

#### Bottom Navigation

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│  ┌─────────┬─────────┬─────────┬─────────┬─────────┐                   │
│  │    🏠   │    📝   │    💳   │    📊   │    📈   │                   │
│  │  首页   │  交易   │  账户   │  预算   │  报表   │                   │
│  └─────────┴─────────┴─────────┴─────────┴─────────┘                   │
│                                                                          │
│  Height: 80dp (including safe area)                                     │
│  Icon: 24dp                                                             │
│  Label: 12sp, Medium                                                    │
│  Active: Primary color                                                  │
│  Inactive: On Surface Variant                                           │
│  Elevation: 8dp                                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Iconography

### 6.1 Icon Set

| Category | Icon Family | Style |
|----------|-------------|-------|
| **UI Icons** | Material Symbols | Rounded |
| **Category Icons** | Custom + Material | Filled |
| **Brand Icons** | Custom | Outlined |

### 6.2 Category Icons

| Category | Icon | Color |
|----------|------|-------|
| **餐饮** | restaurant | #FF5722 |
| **交通** | directions_car | #2196F3 |
| **购物** | shopping_cart | #E91E63 |
| **娱乐** | movie | #9C27B0 |
| **医疗** | local_hospital | #4CAF50 |
| **教育** | school | #FF9800 |
| **工资** | account_balance_wallet | #4CAF50 |
| **奖金** | card_giftcard | #8BC34A |
| **投资** | trending_up | #CDDC39 |
| **其他** | more_horiz | #607D8B |

### 6.3 Icon Sizes

| Usage | Size |
|-------|------|
| **Navigation** | 24dp |
| **List Item** | 24dp |
| **Card Icon** | 48dp |
| **Empty State** | 64dp |
| **Splash** | 120dp |

---

## 7. Motion & Animation

### 7.1 Timing

| Animation | Duration | Easing |
|-----------|----------|--------|
| **Micro** | 100ms | Standard |
| **Small** | 200ms | Standard |
| **Medium** | 300ms | Standard |
| **Large** | 400ms | Standard |
| **Complex** | 500ms | Emphasized |

### 7.2 Transitions

| Transition | Type | Duration |
|------------|------|----------|
| **Page** | Fade + Slide | 300ms |
| **Modal** | Slide Up | 300ms |
| **Dialog** | Fade + Scale | 200ms |
| **List Item** | Fade | 200ms |
| **Button Press** | Scale | 100ms |

### 7.3 Feedback Animations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    FEEDBACK ANIMATIONS                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  成功反馈                                                                │
│  ├── 显示成功图标 (check_circle)                                        │
│  ├── 持续 1500ms                                                        │
│  └── 自动消失                                                           │
│                                                                          │
│  错误反馈                                                                │
│  ├── 抖动动画 (shake)                                                   │
│  ├── 显示错误消息                                                       │
│  └── 持续 3000ms                                                        │
│                                                                          │
│  加载状态                                                                │
│  ├── 显示 CircularProgressIndicator                                    │
│  ├── 禁用交互                                                           │
│  └── 完成后淡出                                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Accessibility

### 8.1 Color Contrast

| Element | Minimum Ratio | Target |
|---------|---------------|--------|
| **Body Text** | 4.5:1 | 7:1 |
| **Large Text** | 3:1 | 4.5:1 |
| **UI Components** | 3:1 | 4.5:1 |

### 8.2 Touch Targets

| Element | Minimum Size | Recommended |
|---------|--------------|-------------|
| **Button** | 48dp x 48dp | 48dp x 48dp |
| **List Item** | 48dp height | 56dp height |
| **Icon Button** | 48dp x 48dp | 48dp x 48dp |

### 8.3 Screen Reader Support

| Element | Requirement |
|---------|-------------|
| **Images** | All decorative images have empty alt |
| **Icons** | All functional icons have labels |
| **Buttons** | Clear action labels |
| **Forms** | Labels associated with inputs |
| **Charts** | Text alternatives provided |

### 8.4 Focus Order

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      FOCUS ORDER                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  添加交易对话框                                                          │
│  1. 收入/支出切换                                                       │
│  2. 金额输入框                                                          │
│  3. 账户选择                                                            │
│  4. 日期选择                                                            │
│ 5. 描述输入框                                                           │
│  6. 备注输入框                                                          │
│  7. 保存按钮                                                            │
│  8. 关闭按钮                                                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Platform Adaptations

### 9.1 iOS Specific

| Element | Adaptation |
|---------|------------|
| **Navigation** | Large title, swipe back |
| **Lists** | Swipe actions for delete/edit |
| **Sharing** | iOS share sheet |
| **Haptics** | Light impact for selections |

### 9.2 Android Specific

| Element | Adaptation |
|---------|------------|
| **Navigation** | Top app bar with overflow menu |
| **Lists** | Long press for context menu |
| **Sharing** | Android share intent |
| **Haptics** | Vibration for important actions |

### 9.3 Web Specific

| Element | Adaptation |
|---------|------------|
| **Navigation** | Sidebar for large screens |
| **Keyboard** | Full keyboard navigation |
| **Mouse** | Hover states |
| **Responsive** | Fluid layouts |

### 9.4 Desktop Specific

| Element | Adaptation |
|---------|------------|
| **Window** | Resizable, minimum 1024x768 |
| **Keyboard** | Shortcuts for common actions |
| **Menu** | Native menu bar |
| **Tray** | System tray icon (optional) |

---

## 10. Chinese Market Adaptations

### 10.1 Number Formatting

| Format | Example | Usage |
|--------|---------|-------|
| **标准** | ¥1,234.56 | 默认 |
| **万** | ¥1.23万 | 大额 |
| **简写** | ¥1.2k | 紧凑空间 |

### 10.2 Date Formatting

| Format | Example | Usage |
|--------|---------|-------|
| **完整** | 2026年5月19日 星期二 | 正式场合 |
| **标准** | 2026年5月19日 | 默认 |
| **简短** | 5月19日 | 列表 |
| **相对** | 今天、昨天、3天前 | 动态 |

### 10.3 Currency Display

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CURRENCY DISPLAY OPTIONS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  设置 > 显示                                                             │
│  ├── 货币符号位置: [符号在前 | 符号在后]                               │
│  ├── 千分位分隔: [逗号 (1,234) | 无]                                   │
│  ├── 大额显示: [标准 | 万为单位]                                        │
│  └── 收支颜色: [现代 (收入绿/支出红) | 传统 (收入红/支出绿)]           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Error Handling

### 11.1 Error Messages

| Error Type | Message | Action |
|------------|---------|--------|
| **Network** | "网络连接失败，请检查网络设置" | 重试按钮 |
| **Validation** | "请输入有效金额" | 高亮输入框 |
| **Permission** | "需要访问相册权限" | 设置引导 |
| **Sync** | "同步失败，请稍后重试" | 重试按钮 |
| **Import** | "文件格式不支持" | 格式说明 |

### 11.2 Empty States

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    EMPTY STATE DESIGN                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                 │   │
│  │                          📝                                     │   │
│  │                                                                 │   │
│  │                    暂无交易记录                                  │   │
│  │                                                                 │   │
│  │              点击下方按钮开始记账                                │   │
│  │                                                                 │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Components:                                                             │
│  ├── Icon: 64dp, Outline color                                          │
│  ├── Title: 16sp, Medium, On Surface                                    │
│  ├── Description: 14sp, Regular, On Surface Variant                     │
│  └── Action: Primary button (optional)                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Design Tokens

### 12.1 Color Tokens

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  // Primary
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);
  
  // Semantic
  static const Color income = Color(0xFF4CAF50);
  static const Color expense = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFB00020);
  
  // Neutral
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  
  // Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
}
```

### 12.2 Spacing Tokens

```dart
// lib/core/theme/app_spacing.dart
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
```

### 12.3 Border Radius Tokens

```dart
// lib/core/theme/app_border_radius.dart
class AppBorderRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 9999.0;
}
```

---

## 13. Design Checklist

### 13.1 Pre-Implementation

- [ ] All colors use design tokens
- [ ] All spacing uses spacing tokens
- [ ] All text uses type scale
- [ ] Touch targets meet minimum size
- [ ] Color contrast meets WCAG AA

### 13.2 Component Review

- [ ] Consistent with Material 3
- [ ] Proper states (hover, focus, pressed, disabled)
- [ ] Accessibility labels
- [ ] Error handling
- [ ] Loading states

### 13.3 Platform Review

- [ ] iOS adaptations implemented
- [ ] Android adaptations implemented
- [ ] Web adaptations implemented
- [ ] Desktop adaptations implemented

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-19 | Initial UI/UX guidelines |