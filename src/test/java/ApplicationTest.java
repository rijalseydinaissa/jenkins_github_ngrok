
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@TestPropertySource(properties = "spring.profiles.active=test")
class ApplicationTest {

    @Test
    void contextLoads() {
        // Test que le contexte Spring Boot se charge correctement
    }
}