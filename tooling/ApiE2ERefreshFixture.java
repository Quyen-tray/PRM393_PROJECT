import java.sql.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;

// Test data bootstrap only. Never replaces the production Google verifier.
class ApiE2ERefreshFixture {
    public static void main(String[] args) throws Exception {
        String url=System.getenv("HRM_TEST_DB_URL");
        if(url==null||!url.matches(".*databaseName=HRM_CoffeeShop_V3_Test(?:_[0-9]+)?(?:;.*)?"))throw new IllegalArgumentException("Dedicated database required");
        long user=Long.parseLong(args[0]);
        byte[] random=new byte[32];new SecureRandom().nextBytes(random);
        String raw=Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8)));
        try(Connection c=DriverManager.getConnection(url,System.getenv("HRM_TEST_DB_USERNAME"),System.getenv("HRM_TEST_DB_PASSWORD"))){
            try(var q=c.prepareStatement("SELECT Email FROM dbo.AppUser WHERE UserId=?")){q.setLong(1,user);try(var r=q.executeQuery()){if(!r.next()||!r.getString(1).startsWith("api-e2e-"))throw new IllegalArgumentException("E2E fixture user required");}}
            try(var q=c.prepareStatement("INSERT INTO dbo.RefreshToken(UserId,TokenHash,ExpiresAt,CreatedAt) VALUES (?,?,DATEADD(day,1,SYSUTCDATETIME()),SYSUTCDATETIME())")){q.setLong(1,user);q.setString(2,hash);q.executeUpdate();}
            String json="{\"userId\":"+user+",\"refreshToken\":\""+raw+"\"}";
            Files.writeString(Path.of(args[1]),json,StandardCharsets.UTF_8);
        }
        System.out.println("Prepared dedicated E2E refresh fixture.");
    }
}
