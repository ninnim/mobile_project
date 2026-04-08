using TimeCapsule.API.DTOs.Post;

namespace TimeCapsule.API.Services;

public interface IPostService
{
    Task<PostResponseDto> CreateAsync(Guid userId, CreatePostDto dto);
    Task<PostResponseDto> UpdateAsync(Guid postId, Guid userId, UpdatePostDto dto);
    Task DeleteAsync(Guid postId, Guid userId);
    Task<PaginatedResponse<PostResponseDto>> GetFeedAsync(int page, int pageSize, Guid? currentUserId = null);
    Task<List<PostResponseDto>> GetByUserAsync(Guid userId, Guid? currentUserId = null);
    Task<bool> LikeAsync(Guid postId, Guid userId);
    Task<bool> UnlikeAsync(Guid postId, Guid userId);
    Task<string> ReactAsync(Guid postId, Guid userId, string reactionType);
    Task RemoveReactionAsync(Guid postId, Guid userId);
    Task<ReactionSummaryDto> GetPostReactorsAsync(Guid postId);
    Task<PostCommentDto> AddCommentAsync(Guid postId, Guid userId, CreateCommentDto dto);
    Task<List<PostCommentDto>> GetCommentsAsync(Guid postId, Guid? currentUserId = null);
    Task<string> ReactToCommentAsync(Guid commentId, Guid userId, string reactionType);
    Task RemoveCommentReactionAsync(Guid commentId, Guid userId);
    Task<ReactionSummaryDto> GetCommentReactorsAsync(Guid commentId);
}
