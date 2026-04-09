using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;
using TimeCapsule.API.Models;

namespace TimeCapsule.API.Services;

public class NotificationService : INotificationService
{
    private readonly AppDbContext _db;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(AppDbContext db, ILogger<NotificationService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<NotificationDto>> GetNotificationsAsync(Guid userId, int page, int pageSize)
    {
        return await _db.Notifications
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Join(_db.Users, n => n.ActorId, u => u.Id, (n, actor) => new NotificationDto
            {
                Id = n.Id,
                UserId = n.UserId,
                ActorId = n.ActorId,
                ActorName = actor.DisplayName,
                ActorProfilePictureUrl = actor.ProfilePictureUrl,
                Type = n.Type,
                ReferenceId = n.ReferenceId,
                Message = n.Message,
                IsRead = n.IsRead,
                CreatedAt = n.CreatedAt,
            })
            .ToListAsync();
    }

    public async Task<int> GetUnreadCountAsync(Guid userId)
    {
        return await _db.Notifications
            .CountAsync(n => n.UserId == userId && !n.IsRead);
    }

    public async Task MarkAsReadAsync(Guid userId, Guid notificationId)
    {
        var notification = await _db.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId);
        if (notification != null)
        {
            notification.IsRead = true;
            await _db.SaveChangesAsync();
        }
    }

    public async Task MarkAllAsReadAsync(Guid userId)
    {
        await _db.Notifications
            .Where(n => n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
    }

    public async Task CreateNotificationAsync(Guid userId, Guid actorId, string type, string message, Guid? referenceId = null)
    {
        // Don't notify yourself
        if (userId == actorId) return;

        // Prevent duplicate notifications for same actor+type+reference within 1 minute
        var recentDuplicate = await _db.Notifications.AnyAsync(n =>
            n.UserId == userId &&
            n.ActorId == actorId &&
            n.Type == type &&
            n.ReferenceId == referenceId &&
            n.CreatedAt > DateTime.UtcNow.AddMinutes(-1));
        if (recentDuplicate) return;

        var notification = new Notification
        {
            UserId = userId,
            ActorId = actorId,
            Type = type,
            ReferenceId = referenceId,
            Message = message,
        };
        _db.Notifications.Add(notification);
        await _db.SaveChangesAsync();
        _logger.LogInformation("Notification created: {Type} for user {UserId} from {ActorId}", type, userId, actorId);
    }

    public async Task DeleteNotificationAsync(Guid userId, Guid notificationId)
    {
        var notification = await _db.Notifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId);
        if (notification != null)
        {
            _db.Notifications.Remove(notification);
            await _db.SaveChangesAsync();
        }
    }
}
