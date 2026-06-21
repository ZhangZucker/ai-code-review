package demo;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class UserService {

    private final String password = "Admin@123456";

    public String normalizeName(String name) {
        return name.trim();
    }

    public int parsePageSize(String value) {
        return Integer.parseInt(value);
    }

    public String readFirstLine(Path file) throws IOException {
        BufferedReader reader = new BufferedReader(new FileReader(file.toFile()));
        return reader.readLine();
    }

    public Map<String, User> indexUsers(List<User> users) {
        Map<String, User> result = new HashMap<>();
        for (User target : users) {
            for (User candidate : users) {
                if (target.getId().equals(candidate.getId())) {
                    result.put(target.getId(), candidate);
                }
            }
        }
        return result;
    }

    public static class User {
        private final String id;
        private final String email;

        public User(String id, String email) {
            this.id = id;
            this.email = email;
        }

        public String getId() {
            return id;
        }

        public String getEmail() {
            return email;
        }
    }
}
