package demo;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class UserService {

    public String normalizeName(String name) {
        if (name == null || name.trim().isEmpty()) {
            throw new IllegalArgumentException("name is required");
        }
        return name.trim();
    }

    public int parsePageSize(String value) {
        try {
            int pageSize = Integer.parseInt(value);
            if (pageSize < 1 || pageSize > 100) {
                throw new IllegalArgumentException("pageSize must be between 1 and 100");
            }
            return pageSize;
        } catch (NumberFormatException exception) {
            throw new IllegalArgumentException("pageSize must be a number", exception);
        }
    }

    public String readFirstLine(Path file) throws IOException {
        try (BufferedReader reader = Files.newBufferedReader(file)) {
            return reader.readLine();
        }
    }

    public Map<String, User> indexUsers(List<User> users) {
        Map<String, User> usersById = new HashMap<>();
        for (User user : users) {
            usersById.put(user.getId(), user);
        }
        return usersById;
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
