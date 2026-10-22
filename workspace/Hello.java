public class Hello {
    public static void main(String[] args) {
        String name = args.length > 0 ? args[0] : "developer";
        System.out.println("Hello, " + name + "! This IDE is running locally.");
    }
}
