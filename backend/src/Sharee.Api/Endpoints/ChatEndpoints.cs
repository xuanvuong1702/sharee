using Microsoft.AspNetCore.SignalR;
using Sharee.Api.Contracts;
using Sharee.Api.Hubs;
using Sharee.Api.Infrastructure;
using Sharee.Api.Services;

namespace Sharee.Api.Endpoints;

public static class ChatEndpoints
{
    public static IEndpointRouteBuilder MapChatEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/conversations").RequireAuthorization().WithTags("Chat");

        group.MapGet("", async (HttpContext http, ChatService chat, CancellationToken ct) =>
        {
            var list = await chat.ListAsync(http.User.GetUserId(), ct);
            return Results.Ok(list);
        });

        group.MapGet("/{id:guid}/messages", async (
            Guid id, HttpContext http, ChatService chat, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            if (!await chat.IsParticipantAsync(id, userId)) return Results.Forbid();
            return Results.Ok(await chat.MessagesAsync(id, userId, ct));
        });

        group.MapPost("/{id:guid}/messages", async (
            Guid id, SendMessageRequest request, HttpContext http, ChatService chat,
            IHubContext<ChatHub> hub, CancellationToken ct) =>
        {
            var userId = http.User.GetUserId();
            if (!await chat.IsParticipantAsync(id, userId)) return Results.Forbid();
            if (string.IsNullOrWhiteSpace(request.Body) || request.Body.Length > 2000)
                return Results.BadRequest(new { error = "Tin nhắn không hợp lệ" });

            var message = await chat.SendAsync(id, userId, request.Body.Trim(), ct);
            var otherId = await chat.GetOtherUserIdAsync(id, userId, ct);
            await hub.Clients.Group($"conv:{id}").SendAsync("message", message, ct);
            await hub.Clients.Group($"user:{otherId}").SendAsync("thread", message, ct);
            return Results.Ok(message);
        });

        return app;
    }
}
