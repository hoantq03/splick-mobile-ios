# Feed comments — iOS implementation

Client implementation for **unlimited-depth comment threads** and **attachments** against live feed + media APIs.

## API contract

| Endpoint | Role |
|----------|------|
| `GET /v1/feed`, `GET /v1/feed/posts/{id}` | Flat `comments[]` with `parentCommentId`, `attachments[]` |
| `POST /v1/feed/posts/{id}/comments` | Create comment (201 empty body) |
| `POST /v1/media/uploads` + complete | Upload bytes (`purpose: COMMENT_ATTACHMENT`) |

Backend docs: `splick-backend/services/feed-service/docs/usecases/UC-F06-add-comment.md`.

## Domain model

### `PostComment` (`SplickDomain`)

- `parentCommentId`: links reply to direct parent (any depth).
- `attachments`: `[CommentAttachment]` with `kind` (`image` \| `video` \| `file`).

Helpers on `[PostComment]`:

```swift
var topLevel: [PostComment]           // parentCommentId == nil
func children(of parentId: UUID) -> [PostComment]
```

### `CommentSubmissionAttachment` (`FeatureSocialFeed`)

Staging model before upload: `kind`, `Data`, `mimeType`, `fileName`.

## Data flow — add comment

```text
CommentComposerView
  → FeedViewModel.addComment(body, submissionAttachments, parentId)
    → AddCommentUseCase
      → FeedRepository.addComment
          1. For each submission: MediaRepository.uploadImage(..., purpose: .commentAttachment)
          2. Build CreateCommentRequestDTO (body?, parentCommentId?, attachments[])
          3. POST /v1/feed/posts/{postId}/comments
  → Optimistic local comment + optional FetchPostUseCase refresh
```

**Important:** `parentCommentId` must be the **id of the comment being replied to**, not the root of the thread.

## UI — thread rendering

`CommentThreadView` renders recursively:

1. Input: full `comments` array + `roots` (top-level or children of a node).
2. For each root → `CommentRowView` + recurse with `comments.children(of: root.id)`.
3. Indent = `depth * 20pt`.

Used from `PostDetailView` with `commentPager.allComments` (full flat list from post).

## UI — composer

`CommentComposerView`:

| Source | Attachment kind |
|--------|-----------------|
| `PhotosPicker` (images + videos) | `.image` or `.video` |
| `fileImporter` | `.file` |

Submit allowed when trimmed text **or** at least one pending attachment.

## Pagination note

`PostDetailViewModel` paginates **top-level** comments only (`displayedTopLevel`). Replies at any depth are shown when their ancestor top-level comment is loaded (tree built from full `allComments`).

## Files map

| File | Responsibility |
|------|----------------|
| `SplickDomain/.../PostComment.swift` | Entity + tree helpers |
| `FeatureSocialFeed/.../CommentThreadView.swift` | Recursive UI |
| `FeatureSocialFeed/.../CommentComposerView.swift` | Input + pickers |
| `FeatureSocialFeed/.../FeedRepository.swift` | Upload + POST |
| `FeatureSocialFeed/.../FeedMapper.swift` | DTO ↔ domain |
| `FeatureSocialFeed/.../FetchPostUseCase.swift` | Refresh post after comment |
| `FeatureMedia/.../MediaUploadPurpose.swift` | `.commentAttachment` |

## Manual test checklist

- [ ] Reply to a reply (depth ≥ 3) — indent increases each level
- [ ] Comment with photo only (no text)
- [ ] Comment with PDF / file
- [ ] Refresh post — server ids and attachment URLs match
- [ ] media-service + feed-service running (gateway `:8080`)

## Related backend migrations

Feed DB **V5** (`post_comment_attachments`) required for attachment persistence.
