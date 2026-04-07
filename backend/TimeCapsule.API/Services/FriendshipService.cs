using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.DTOs.Friendship;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class FriendshipService : IFriendshipService
{
    private readonly AppDbContext _db;
    private readonly ILogger<FriendshipService> _logger;

    public FriendshipService(AppDbContext db, ILogger<FriendshipService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<UserSearchDto>> SearchUsersAsync(Guid currentUserId, string query)
    {
        var q = query.Trim().ToLower();
        if (q.Length < 2) return new List<UserSearchDto>();

        var users = await _db.Users
            .Where(u => u.Id != currentUserId &&
                (u.DisplayName.ToLower().Contains(q) || u.Email.ToLower().Contains(q)))
            .Take(20)
            .ToListAsync();

        var result = new List<UserSearchDto>();
        foreach (var u in users)
        {
            var status = await GetFriendshipStatusAsync(currentUserId, u.Id);
            result.Add(new UserSearchDto
            {
                Id = u.Id,
                DisplayName = u.DisplayName,
                Email = u.Email,
                ProfilePictureUrl = u.ProfilePictureUrl,
                FriendshipStatus = status
            });
        }
        return result;
    }

    public async Task<FriendDto> SendFriendRequestAsync(Guid requesterId, Guid addresseeId)
    {
        if (requesterId == addresseeId)
            throw new InvalidOperationException("Cannot send friend request to yourself.");

        var exists = await _db.Friendships.AnyAsync(f =>
            (f.RequesterId == requesterId && f.AddresseeId == addresseeId) ||
            (f.RequesterId == addresseeId && f.AddresseeId == requesterId));

        if (exists)
            throw new InvalidOperationException("Friendship already exists.");

        var addressee = await _db.Users.FindAsync(addresseeId)
            ?? throw new KeyNotFoundException("User not found.");

        var friendship = new Friendship
        {
            RequesterId = requesterId,
            AddresseeId = addresseeId,
            Status = "Pending"
        };
        _db.Friendships.Add(friendship);
        await _db.SaveChangesAsync();
        _logger.LogInformation("Friend request sent from {From} to {To}", requesterId, addresseeId);

        return new FriendDto
        {
            UserId = addresseeId,
            DisplayName = addressee.DisplayName,
            ProfilePictureUrl = addressee.ProfilePictureUrl,
            Status = "Pending",
            IsRequester = true,
            CreatedAt = friendship.CreatedAt
        };
    }

    public async Task<FriendDto> AcceptFriendRequestAsync(Guid currentUserId, Guid requesterId)
    {
        var friendship = await _db.Friendships
            .Include(f => f.Requester)
            .FirstOrDefaultAsync(f => f.RequesterId == requesterId && f.AddresseeId == currentUserId && f.Status == "Pending")
            ?? throw new KeyNotFoundException("Friend request not found.");

        friendship.Status = "Accepted";
        friendship.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return new FriendDto
        {
            UserId = requesterId,
            DisplayName = friendship.Requester.DisplayName,
            ProfilePictureUrl = friendship.Requester.ProfilePictureUrl,
            Status = "Accepted",
            IsRequester = false,
            CreatedAt = friendship.CreatedAt
        };
    }

    public async Task DeclineFriendRequestAsync(Guid currentUserId, Guid requesterId)
    {
        var friendship = await _db.Friendships
            .FirstOrDefaultAsync(f =>
                (f.RequesterId == requesterId && f.AddresseeId == currentUserId) ||
                (f.RequesterId == currentUserId && f.AddresseeId == requesterId))
            ?? throw new KeyNotFoundException("Friend request not found.");

        _db.Friendships.Remove(friendship);
        await _db.SaveChangesAsync();
    }

    public async Task RemoveFriendAsync(Guid currentUserId, Guid otherUserId)
    {
        var friendship = await _db.Friendships
            .FirstOrDefaultAsync(f =>
                (f.RequesterId == currentUserId && f.AddresseeId == otherUserId) ||
                (f.RequesterId == otherUserId && f.AddresseeId == currentUserId))
            ?? throw new KeyNotFoundException("Friendship not found.");

        _db.Friendships.Remove(friendship);
        await _db.SaveChangesAsync();
        _logger.LogInformation("Friendship removed between {A} and {B}", currentUserId, otherUserId);
    }

    public async Task<List<FriendDto>> GetFriendsAsync(Guid userId)
    {
        var friendships = await _db.Friendships
            .Include(f => f.Requester)
            .Include(f => f.Addressee)
            .Where(f => (f.RequesterId == userId || f.AddresseeId == userId) && f.Status == "Accepted")
            .ToListAsync();

        return friendships.Select(f =>
        {
            var isRequester = f.RequesterId == userId;
            var friend = isRequester ? f.Addressee : f.Requester;
            return new FriendDto
            {
                UserId = friend.Id,
                DisplayName = friend.DisplayName,
                ProfilePictureUrl = friend.ProfilePictureUrl,
                Status = "Accepted",
                IsRequester = isRequester,
                CreatedAt = f.CreatedAt
            };
        }).ToList();
    }

    public async Task<List<FriendDto>> GetIncomingRequestsAsync(Guid userId)
    {
        var requests = await _db.Friendships
            .Include(f => f.Requester)
            .Where(f => f.AddresseeId == userId && f.Status == "Pending")
            .ToListAsync();

        return requests.Select(f => new FriendDto
        {
            UserId = f.RequesterId,
            DisplayName = f.Requester.DisplayName,
            ProfilePictureUrl = f.Requester.ProfilePictureUrl,
            Status = "Pending",
            IsRequester = false,
            CreatedAt = f.CreatedAt
        }).ToList();
    }

    public async Task<string> GetFriendshipStatusAsync(Guid currentUserId, Guid otherUserId)
    {
        var friendship = await _db.Friendships.FirstOrDefaultAsync(f =>
            (f.RequesterId == currentUserId && f.AddresseeId == otherUserId) ||
            (f.RequesterId == otherUserId && f.AddresseeId == currentUserId));

        if (friendship == null) return "None";
        if (friendship.Status == "Accepted") return "Accepted";
        if (friendship.Status == "Pending")
        {
            return friendship.RequesterId == currentUserId ? "Pending" : "Requested";
        }
        return "None";
    }
}
