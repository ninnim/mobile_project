using System.Collections.Concurrent;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using TimeCapsule.API.Data;

namespace TimeCapsule.API.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private static readonly ConcurrentDictionary<string, HashSet<string>> _userConnections = new();
    private readonly AppDbContext _db;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(AppDbContext db, ILogger<ChatHub> logger)
    {
        _db = db;
        _logger = logger;
    }

    private Guid GetUserId() => Guid.Parse(Context.User!.FindFirstValue(ClaimTypes.NameIdentifier)!);

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId().ToString();
        _userConnections.AddOrUpdate(userId,
            _ => new HashSet<string> { Context.ConnectionId },
            (_, set) => { lock (set) { set.Add(Context.ConnectionId); } return set; });

        // Mark user online
        var user = await _db.Users.FindAsync(Guid.Parse(userId));
        if (user != null)
        {
            user.IsOnline = true;
            user.LastSeen = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        _logger.LogInformation("User {UserId} connected (connId: {ConnectionId})", userId, Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = GetUserId().ToString();
        if (_userConnections.TryGetValue(userId, out var connections))
        {
            lock (connections) { connections.Remove(Context.ConnectionId); }
            if (connections.Count == 0)
            {
                _userConnections.TryRemove(userId, out _);

                var user = await _db.Users.FindAsync(Guid.Parse(userId));
                if (user != null)
                {
                    user.IsOnline = false;
                    user.LastSeen = DateTime.UtcNow;
                    await _db.SaveChangesAsync();
                }
            }
        }

        _logger.LogInformation("User {UserId} disconnected", userId);
        await base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// Relay a new message notification to the recipient in real-time.
    /// The actual message saving happens via the REST API.
    /// </summary>
    public async Task SendMessage(object message, string receiverId)
    {
        if (_userConnections.TryGetValue(receiverId, out var connections))
        {
            HashSet<string> snapshot;
            lock (connections) { snapshot = new HashSet<string>(connections); }
            foreach (var connId in snapshot)
            {
                await Clients.Client(connId).SendAsync("ReceiveMessage", message);
            }
        }
    }

    public async Task Typing(string receiverId, bool isTyping)
    {
        var senderId = GetUserId().ToString();
        if (_userConnections.TryGetValue(receiverId, out var connections))
        {
            HashSet<string> snapshot;
            lock (connections) { snapshot = new HashSet<string>(connections); }
            foreach (var connId in snapshot)
            {
                await Clients.Client(connId).SendAsync("UserTyping", senderId, isTyping);
            }
        }
    }

    public async Task MessageRead(string otherUserId, List<string> messageIds)
    {
        var userId = GetUserId().ToString();
        if (_userConnections.TryGetValue(otherUserId, out var connections))
        {
            HashSet<string> snapshot;
            lock (connections) { snapshot = new HashSet<string>(connections); }
            foreach (var connId in snapshot)
            {
                await Clients.Client(connId).SendAsync("MessagesRead", userId, messageIds);
            }
        }
    }

    public async Task ReactionUpdated(string otherUserId, object reactionData)
    {
        if (_userConnections.TryGetValue(otherUserId, out var connections))
        {
            HashSet<string> snapshot;
            lock (connections) { snapshot = new HashSet<string>(connections); }
            foreach (var connId in snapshot)
            {
                await Clients.Client(connId).SendAsync("ReactionUpdated", reactionData);
            }
        }
    }

    public static bool IsUserOnline(string userId)
        => _userConnections.ContainsKey(userId) && _userConnections[userId].Count > 0;

    public static HashSet<string> GetConnectionIds(string userId)
    {
        if (_userConnections.TryGetValue(userId, out var connections))
        {
            lock (connections) { return new HashSet<string>(connections); }
        }
        return new HashSet<string>();
    }
}
