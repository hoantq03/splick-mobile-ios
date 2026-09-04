# Feed comments — iOS implementation

Unlimited-depth comment threads with shared `@mention` styling across the app.

## Thread model

- Flat `comments[]` from API with `parentCommentId` pointing to the **direct parent**.
- `CommentThreadView` renders **recursively**; each nesting level adds a left connector + `40pt` indent.
- `POST /comments` sends `parentCommentId` = id of the comment being replied to (no flattening).

## Mention styling (DesignSystem)

| Component | Use |
|-----------|-----|
| `MentionText` | Read-only: comments, captions, notifications, expense list |
| `MentionTextField` | Typing: comment composer, create post caption, bill reminder, create expense |
| `MentionStyler` | Parser + `NSAttributedString` for live editor styling |
| `MentionContext` | Active `@` query for friend picker |

`@username` → **semibold + `SplickTheme.Colors.info`** everywhere.

## UI

- `CommentThreadView` — recursive tree, "Xem thêm N phản hồi" per parent
- `CommentReplyBanner` + `CommentComposerView` — reply mode, focus, `@` prefill
- `PostDetailView` — scroll to new comment after submit

## Files map

| File | Responsibility |
|------|----------------|
| `SplickCore/.../Mentions/*` | Shared mention UI |
| `CommentThreadView.swift` | Recursive comment UI |
| `PostDetailViewModel.swift` | Top-level pagination + expanded parents |
| `FeedViewModel.swift` | Optimistic add comment; server refresh replaces phantom (no re-merge) |
