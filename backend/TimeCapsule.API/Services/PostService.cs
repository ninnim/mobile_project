using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Post;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class PostService : IPostService
{
    private static readonly HashSet<string> ValidReactions = new(StringComparer.OrdinalIgnoreCase)
        { "like", "love", "haha", "wow", "sad", "angry" };

    private readonly AppDbContext _db;
    private readonly IFileUploadService _fileUpload;
    private readonly ILogger<PostService> _logger;

    public PostService(AppDbContext db, IFileUploadService fileUpload, ILogger<PostService> logger)
    { _db = db; _fileUpload = fileUpload; _logger = logger; }

    private IQueryable<Post> PostsWithIncludes() => _db.Posts
        .Include(p => p.User)
        .Include(p => p.Likes)
        .Include(p => p.Comments)
        .Include(p => p.Tags).ThenInclude(t => t.User)
        .Include(p => p.Reactions)
        .Include(p => p.SharedPost).ThenInclude(sp => sp!.User);

    public async Task<PostResponseDto> CreateAsync(Guid userId, CreatePostDto dto)
    {
        string? mediaUrl = null;
        if (dto.MediaFile != null)
            mediaUrl = await _fileUpload.SaveFileAsync(dto.MediaFile);

        var post = new Post
        {
            Id = Guid.NewGuid(), UserId = userId,
            Content = dto.Content, MediaUrl = mediaUrl,
            SharedPostId = dto.SharedPostId,
            CreatedAt = DateTime.UtcNow
        };
        _db.Posts.Add(post);
        await _db.SaveChangesAsync();

        // Handle tagged users
        if (!string.IsNullOrWhiteSpace(dto.TaggedUserIds))
        {
            var tagIds = dto.TaggedUserIds.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(s => Guid.TryParse(s, out var g) ? g : (Guid?)null)
                .Where(g => g.HasValue && g.Value != userId)
                .Select(g => g!.Value)
                .Distinct()
                .Take(20)
                .ToList();

            var validUsers = await _db.Users.Where(u => tagIds.Contains(u.Id)).Select(u => u.Id).ToListAsync();
            foreach (var tagUserId in validUsers)
            {
                _db.PostTags.Add(new PostTag { PostId = post.Id, UserId = tagUserId });
            }
            if (validUsers.Count > 0) await _db.SaveChangesAsync();
        }

        var fullPost = await PostsWithIncludes().FirstAsync(p => p.Id == post.Id);
        return MapToDto(fullPost, fullPost.User);
    }

    public async Task<PostResponseDto> UpdateAsync(Guid postId, Guid userId, UpdatePostDto dto)
    {
        var post = await _db.Posts.FirstOrDefaultAsync(p => p.Id == postId)
            ?? throw new KeyNotFoundException("Post not found.");
        if (post.UserId != userId)
            throw new UnauthorizedAccessException("You can only edit your own posts.");

        post.Content = dto.Content;

        if (dto.RemoveMedia)
            post.MediaUrl = null;
        else if (dto.MediaFile != null)
            post.MediaUrl = await _fileUpload.SaveFileAsync(dto.MediaFile);

        await _db.SaveChangesAsync();

        var fullPost = await PostsWithIncludes().FirstAsync(p => p.Id == post.Id);
        return MapToDto(fullPost, fullPost.User, userId);
    }

    public async Task DeleteAsync(Guid postId, Guid userId)
    {
        var post = await _db.Posts.FirstOrDefaultAsync(p => p.Id == postId)
            ?? throw new KeyNotFoundException("Post not found.");
        if (post.UserId != userId)
            throw new UnauthorizedAccessException("You can only delete your own posts.");

        _db.Posts.Remove(post);
        await _db.SaveChangesAsync();
    }

    public async Task<PaginatedResponse<PostResponseDto>> GetFeedAsync(int page, int pageSize, Guid? currentUserId = null)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var total = await _db.Posts.CountAsync();
        var items = await PostsWithIncludes()
            .OrderByDescending(p => p.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();
        return new PaginatedResponse<PostResponseDto>
        {
            Items = items.Select(p => MapToDto(p, p.User, currentUserId)).ToList(),
            Page = page, PageSize = pageSize,
            TotalCount = total, TotalPages = (int)Math.Ceiling(total / (double)pageSize)
        };
    }

    public async Task<List<PostResponseDto>> GetByUserAsync(Guid userId, Guid? currentUserId = null)
    {
        var posts = await PostsWithIncludes()
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();
        return posts.Select(p => MapToDto(p, p.User, currentUserId)).ToList();
    }

    public async Task<bool> LikeAsync(Guid postId, Guid userId)
    {
        var exists = await _db.PostLikes.AnyAsync(l => l.PostId == postId && l.UserId == userId);
        if (exists) return false;
        _db.PostLikes.Add(new PostLike { PostId = postId, UserId = userId });
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<bool> UnlikeAsync(Guid postId, Guid userId)
    {
        var like = await _db.PostLikes.FirstOrDefaultAsync(l => l.PostId == postId && l.UserId == userId);
        if (like == null) return false;
        _db.PostLikes.Remove(like);
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task<string> ReactAsync(Guid postId, Guid userId, string reactionType)
    {
        reactionType = reactionType.ToLowerInvariant();
        if (!ValidReactions.Contains(reactionType))
            throw new ArgumentException($"Invalid reaction type. Valid types: {string.Join(", ", ValidReactions)}");

        var post = await _db.Posts.AnyAsync(p => p.Id == postId);
        if (!post) throw new KeyNotFoundException("Post not found.");

        var existing = await _db.PostReactions
            .FirstOrDefaultAsync(r => r.PostId == postId && r.UserId == userId);

        if (existing != null)
        {
            existing.ReactionType = reactionType;
            existing.CreatedAt = DateTime.UtcNow;
        }
        else
        {
            _db.PostReactions.Add(new PostReaction
            {
                Id = Guid.NewGuid(),
                PostId = postId,
                UserId = userId,
                ReactionType = reactionType,
                CreatedAt = DateTime.UtcNow
            });
        }

        await _db.SaveChangesAsync();
        return reactionType;
    }

    public async Task RemoveReactionAsync(Guid postId, Guid userId)
    {
        var reaction = await _db.PostReactions
            .FirstOrDefaultAsync(r => r.PostId == postId && r.UserId == userId);
        if (reaction != null)
        {
            _db.PostReactions.Remove(reaction);
            await _db.SaveChangesAsync();
        }
    }

    public async Task<PostCommentDto> AddCommentAsync(Guid postId, Guid userId, CreateCommentDto dto)
    {
        var post = await _db.Posts.FindAsync(postId) ?? throw new KeyNotFoundException("Post not found.");
        var user = await _db.Users.FindAsync(userId);
        var comment = new PostComment { PostId = postId, UserId = userId, Content = dto.Content.Trim() };
        _db.PostComments.Add(comment);
        await _db.SaveChangesAsync();
        return new PostCommentDto
        {
            Id = comment.Id, UserId = userId,
            UserName = user?.DisplayName ?? "",
            UserProfilePicture = user?.ProfilePictureUrl,
            Content = comment.Content, CreatedAt = comment.CreatedAt
        };
    }

    public async Task<List<PostCommentDto>> GetCommentsAsync(Guid postId)
    {
        return await _db.PostComments
            .Include(c => c.User)
            .Where(c => c.PostId == postId)
            .OrderBy(c => c.CreatedAt)
            .Select(c => new PostCommentDto
            {
                Id = c.Id, UserId = c.UserId,
                UserName = c.User.DisplayName,
                UserProfilePicture = c.User.ProfilePictureUrl,
                Content = c.Content, CreatedAt = c.CreatedAt
            })
            .ToListAsync();
    }

    private PostResponseDto MapToDto(Post p, User? u, Guid? currentUserId = null)
    {
        var reactions = p.Reactions ?? new List<PostReaction>();
        var reactionCounts = reactions
            .GroupBy(r => r.ReactionType.ToLowerInvariant())
            .ToDictionary(g => g.Key, g => g.Count());

        SharedPostDto? sharedPost = null;
        if (p.SharedPostId.HasValue)
        {
            if (p.SharedPost != null)
            {
                sharedPost = new SharedPostDto
                {
                    Id = p.SharedPost.Id,
                    UserId = p.SharedPost.UserId,
                    UserName = p.SharedPost.User?.DisplayName ?? "",
                    UserProfilePicture = p.SharedPost.User?.ProfilePictureUrl,
                    Content = p.SharedPost.Content,
                    MediaUrl = p.SharedPost.MediaUrl,
                    CreatedAt = p.SharedPost.CreatedAt
                };
            }
            else
            {
                // Original post was deleted — return a marker for "unavailable"
                sharedPost = new SharedPostDto
                {
                    Id = p.SharedPostId.Value,
                    UserId = Guid.Empty,
                    UserName = "",
                    Content = "",
                    CreatedAt = DateTime.MinValue
                };
            }
        }

        return new PostResponseDto
        {
            Id = p.Id, UserId = p.UserId, UserName = u?.DisplayName ?? "",
            UserProfilePicture = u?.ProfilePictureUrl, Content = p.Content,
            MediaUrl = p.MediaUrl, CreatedAt = p.CreatedAt,
            LikeCount = reactions.Count,
            CommentCount = p.Comments?.Count ?? 0,
            IsLikedByMe = currentUserId.HasValue && reactions.Any(r => r.UserId == currentUserId.Value),
            ReactionCounts = reactionCounts,
            MyReaction = currentUserId.HasValue
                ? reactions.FirstOrDefault(r => r.UserId == currentUserId.Value)?.ReactionType
                : null,
            SharedPost = sharedPost,
            TaggedUsers = p.Tags?.Select(t => new TaggedUserDto
            {
                UserId = t.UserId,
                DisplayName = t.User?.DisplayName ?? "",
                ProfilePictureUrl = t.User?.ProfilePictureUrl
            }).ToList() ?? new()
        };
    }
}
