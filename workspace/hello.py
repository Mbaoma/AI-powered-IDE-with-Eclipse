import sys


def greet(name: str) -> str:
    message = f"Hello, {name}! This IDE is running locally."
    print(message)
    return message


if __name__ == "__main__":
    greet(sys.argv[1] if len(sys.argv) > 1 else "developer")
