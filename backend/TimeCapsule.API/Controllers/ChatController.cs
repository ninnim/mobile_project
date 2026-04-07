using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TimeCapsule.API.DTOs.Chat;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/chats")]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly IChatService _chats;
    public ChatController(IChatService chats) { _chats = chats; }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost]
    public async Task<IActionResult> Send([FromForm] SendMessageDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        try { return StatusCode(201, await _chats.SendAsync(UserId, dto)); }
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
}
