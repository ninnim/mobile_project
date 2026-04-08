using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Post;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class PostService : IPostService
{
    private readonly AppDbContext _db;
    private readonly IFileUploadService _fileUpload;
    private readonly ILogger<PostService> _logger;

    public PostService(AppDbContext db, IFileUploadService fileUpload, ILogger<PostService> logger)
    { _db = db; _fileUpload = fileUpload; _logger = logger; }

    public async Task<PostResponseDto> CreateAsync(Guid userId, CreatePostDto dto)
    {
        string? mediaUrl = null;
        if (dto.MediaFile != null)
            mediaUrl = await _fileUpload.SaveFileAsync(dto.MediaFile);

        var post = new Post
        {
            Id = Guid.NewGuid(), UserId = userId,
            Content = dto.Content, MediaUrl = mediaUrl, CreatedAt = DateTime.UtcNow
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

        // Re-fetch with includes for proper DTO mapping
        var fullPost = await _db.Posts
            .Include(p => p.User)
            .Include(p => p.Likes)
            .Include(p => p.Comments)
            .Include(p => p.Tags).ThenInclude(t => t.User)
            .FirstAsync(p => p.Id == post.Id);
        return MapToDto(fullPost, fullPost.User);
    }

    public async Task<PaginatedResponse<PostResponseDto>> GetFeedAsync(int page, int pageSize, Guid? currentUserId = null)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var total = await _db.Posts.CountAsync();
        var items = await _db.Posts
            .Include(p => p.User)
            .Include(p => p.Likes)
            .Include(p => p.Comments)
            .Include(p => p.Tags).ThenInclude(t => t.User)
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
        var posts = await _db.Posts
            .Include(p => p.User)
            .Include(p => p.Likes)
            .Include(p => p.Comments)
            .Include(p => p.Tags).ThenInclude(t => t.User)
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

    private PostResponseDto MapToDto(Post p, User? u, Guid? currentUserId = null) => new()
    {
        Id = p.Id, UserId = p.UserId, UserName = u?.DisplayName ?? "",
        UserProfilePicture = u?.ProfilePictureUrl, Content = p.Content,
        MediaUrl = p.MediaUrl, CreatedAt = p.CreatedAt,
        LikeCount = p.Likes?.Count ?? 0,
        CommentCount = p.Comments?.Count ?? 0,
        IsLikedByMe = currentUserId.HasValue && (p.Likes?.Any(l => l.UserId == currentUserId.Value) ?? false),
        TaggedUsers = p.Tags?.Select(t => new TaggedUserDto
        {
            UserId = t.UserId,
            DisplayName = t.User?.DisplayName ?? "",
            ProfilePictureUrl = t.User?.ProfilePictureUrl
        }).ToList() ?? new()
    };
}
