import java.io.*;
import java.time.LocalDateTime;

public class UnstableApp {
    private static final String PID_FILE = "app.pid";
    private static final String LOG_FILE = "application.log";

    public static void main(String[] args) throws InterruptedException, IOException {
        System.out.println(">>> Starting Service...");
        createPidFile();
        log("INFO: Service started successfully.");

        for(int i = 1; i <= 15; i++) {
            log("Service processing Request #" + i);
            Thread.sleep(1000);
        }

        System.err.println("CRITICAL ERROR: Out of Memory");
        log("CRITICAL: System crash due to memory overflow");

        new File(PID_FILE).delete();

        System.exit(1);
    }

    private static void log(String message) throws IOException {
        FileWriter writer = new FileWriter(LOG_FILE, true);
        writer.write(LocalDateTime.now() + " - " + message + "\n");
        writer.close();
        System.out.println(message);
    }

    private static void createPidFile() throws IOException {
        File file = new File(PID_FILE);
        file.createNewFile();
    }
}