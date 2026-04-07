using TimeCapsule.API.DTOs.Friendship;

namespace TimeCapsule.API.Services;

public interface IFriendshipService
{
    Task<List<UserSearchDto>> SearchUsersAsync(Guid currentUserId, string query);
    Task<FriendDto> SendFriendRequestAsync(Guid requesterId, Guid addresseeId);
    Task<FriendDto> AcceptFriendRequestAsync(Guid currentUserId, Guid requesterId);
    Task DeclineFriendRequestAsync(Guid currentUserId, Guid requesterId);
    Task RemoveFriendAsync(Guid currentUserId, Guid otherUserId);
    Task<List<FriendDto>> GetFriendsAsync(Guid userId);
    Task<List<FriendDto>> GetIncomingRequestsAsync(Guid userId);
    Task<string> GetFriendshipStatusAsync(Guid currentUserId, Guid otherUserId);
}
