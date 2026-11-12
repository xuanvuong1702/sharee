using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using Sharee.Api.Infrastructure;

namespace Sharee.Api.Services;

public sealed class TokenService(JwtOptions options)
{
    public string CreateToken(Guid id, string phone, string name, string role)
    {
        var claims = new[]
        {
            new Claim("sub", id.ToString()),
            new Claim("phone", phone),
            new Claim("name", name),
            new Claim("role", role),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(options.Key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: options.Issuer,
            audience: options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddDays(options.ExpiryDays),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
