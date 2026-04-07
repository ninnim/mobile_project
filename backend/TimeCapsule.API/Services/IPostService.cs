using TimeCapsule.API.DTOs.Post;

namespace TimeCapsule.API.Services;

public interface IPostService
{
    Task<PostResponseDto> CreateAsync(Guid userId, CreatePostDto dto);
    Task<PaginatedResponse<PostResponseDto>> GetFeedAsync(int page, int pageSize, Guid? currentUserId = null);
    Task<List<PostResponseDto>> GetByUserAsync(Guid userId, Guid? currentUserId = null);
    Task<bool> LikeAsync(Guid postId, Guid userId);
    Task<bool> UnlikeAsync(Guid postId, Guid userId);
    Task<PostCommentDto> AddCommentAsync(Guid postId, Guid userId, CreateCommentDto dto);
    Task<List<PostCommentDto>> GetCommentsAsync(Guid postId);
}
