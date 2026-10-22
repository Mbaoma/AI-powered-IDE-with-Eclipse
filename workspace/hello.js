function greet(name) {
  const message = `Hello, ${name}! This IDE is running locally.`;
  console.log(message);
  return message;
}

greet(process.argv[2] || "developer");
