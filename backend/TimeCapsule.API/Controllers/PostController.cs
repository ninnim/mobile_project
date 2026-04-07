using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TimeCapsule.API.DTOs.Post;
using TimeCapsule.API.Services;

namespace TimeCapsule.API.Controllers;

[ApiController]
[Route("api/posts")]
[Authorize]
public class PostController : ControllerBase
{
    private readonly IPostService _posts;
    public PostController(IPostService posts) { _posts = posts; }
    private Guid UserId => Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpPost]
    public async Task<IActionResult> Create([FromForm] CreatePostDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(new { error = "Invalid input." });
        try { return StatusCode(201, await _posts.CreateAsync(UserId, dto)); }
        catch (Exception ex) { return BadRequest(new { error = ex.Message }); }
    }

    [HttpGet]
    public async Task<IActionResult> GetFeed([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        if (page < 1) return BadRequest(new { error = "Page must be >= 1." });
        if (pageSize < 1 || pageSize > 50) return BadRequest(new { error = "PageSize must be 1-50." });
        return Ok(await _posts.GetFeedAsync(page, pageSize, UserId));
    }

    [HttpGet("user/{userId:guid}")]
    public async Task<IActionResult> GetByUser(Guid userId)
        => Ok(await _posts.GetByUserAsync(userId, UserId));

    [HttpPost("{id:guid}/like")]
    public async Task<IActionResult> Like(Guid id)
    {
        await _posts.LikeAsync(id, UserId);
        return Ok();
    }

    [HttpDelete("{id:guid}/like")]
    public async Task<IActionResult> Unlike(Guid id)
    {
        await _posts.UnlikeAsync(id, UserId);
        return Ok();
    }

    [HttpPost("{id:guid}/comments")]
    public async Task<IActionResult> AddComment(Guid id, [FromBody] CreateCommentDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Content)) return BadRequest(new { error = "Comment cannot be empty." });
        try { return StatusCode(201, await _posts.AddCommentAsync(id, UserId, dto)); }
        catch (KeyNotFoundException ex) { return NotFound(new { error = ex.Message }); }
    }

    [HttpGet("{id:guid}/comments")]
    public async Task<IActionResult> GetComments(Guid id)
        => Ok(await _posts.GetCommentsAsync(id));
}
