namespace TimeCapsule.API.DTOs.Post;

public class PostResponseDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string? UserProfilePicture { get; set; }
    public string Content { get; set; } = string.Empty;
    public string? MediaUrl { get; set; }
    public int LikeCount { get; set; }
    public int CommentCount { get; set; }
    public bool IsLikedByMe { get; set; }
    public Dictionary<string, int> ReactionCounts { get; set; } = new();
    public string? MyReaction { get; set; }
    public SharedPostDto? SharedPost { get; set; }
    public List<TaggedUserDto> TaggedUsers { get; set; } = new();
    public DateTime CreatedAt { get; set; }
}

public class SharedPostDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string? UserProfilePicture { get; set; }
    public string Content { get; set; } = string.Empty;
    public string? MediaUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class TaggedUserDto
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }
}

public class PostCommentDto
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string? UserProfilePicture { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public Dictionary<string, int> ReactionCounts { get; set; } = new();
    public string? MyReaction { get; set; }
    public int TotalReactions { get; set; }
}

public class CreateCommentDto
{
    public string Content { get; set; } = string.Empty;
}

public class ReactorDto
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }
    public string ReactionType { get; set; } = string.Empty;
}

public class ReactionSummaryDto
{
    public Dictionary<string, int> Counts { get; set; } = new();
    public int Total { get; set; }
    public List<ReactorDto> Reactors { get; set; } = new();
}

public class ProfileReactionDto
{
    public Dictionary<string, int> ReactionCounts { get; set; } = new();
    public int TotalReactions { get; set; }
    public string? MyReaction { get; set; }
    public List<ReactorDto> TopReactors { get; set; } = new();
}
