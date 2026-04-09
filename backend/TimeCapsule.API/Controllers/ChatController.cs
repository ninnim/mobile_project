using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using TimeCapsule.API.DTOs.Chat;
using TimeCapsule.API.Hubs;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/chats")]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly IChatService _chats;
    private readonly IHubContext<ChatHub> _hub;
    private readonly INotificationService _notifications;
    public ChatController(IChatService chats, IHubContext<ChatHub> hub, INotificationService notifications) { _chats = chats; _hub = hub; _notifications = notifications; }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost]
    public async Task<IActionResult> Send([FromForm] SendMessageDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        try
        {
            var msg = await _chats.SendAsync(UserId, dto);
            // Relay via SignalR to the receiver
            if (ChatHub.IsUserOnline(dto.ReceiverId.ToString()))
            {
                await _hub.Clients.User(dto.ReceiverId.ToString()).SendAsync("ReceiveMessage", msg);
            }
            // Create a notification for the chat message
            var senderName = User.FindFirstValue("DisplayName") ?? "Someone";
            var preview = dto.Message?.Length > 50 ? dto.Message[..50] + "..." : dto.Message ?? "sent a message";
            await _notifications.CreateNotificationAsync(
                dto.ReceiverId, UserId, "ChatMessage", $"sent you a message: \"{preview}\"");
            return StatusCode(201, msg);
        }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpGet("{userId:guid}")]
    public async Task<IActionResult> GetConversation(Guid userId, [FromQuery] DateTime? before, [FromQuery] int limit = 30)
        => Ok(await _chats.GetConversationAsync(UserId, userId, before, Math.Clamp(limit, 1, 100)));

    [HttpGet("contacts")]
    public async Task<IActionResult> GetContacts()
        => Ok(await _chats.GetContactsAsync(UserId));

    [HttpPut("read/{userId:guid}")]
    public async Task<IActionResult> MarkAsRead(Guid userId)
    {
        await _chats.MarkAsReadAsync(UserId, userId);
        return Ok();
    }

    [HttpPut("deliver/{userId:guid}")]
    public async Task<IActionResult> MarkDelivered(Guid userId)
    {
        await _chats.MarkAsDeliveredAsync(UserId, userId);
        return Ok();
    }

    [HttpPost("{messageId:guid}/react")]
    public async Task<IActionResult> ReactToMessage(Guid messageId, [FromBody] ReactToMessageDto dto)
    {
        try
        {
            var reaction = await _chats.ReactToMessageAsync(UserId, messageId, dto.ReactionType);
            return Ok(reaction);
        }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
        catch (UnauthorizedAccessException ex) { return StatusCode(403, new { error = ex.Message }); }
    }

    [HttpDelete("{messageId:guid}/react")]
    public async Task<IActionResult> RemoveReaction(Guid messageId)
    {
        await _chats.RemoveReactionAsync(UserId, messageId);
        return Ok();
    }
}
