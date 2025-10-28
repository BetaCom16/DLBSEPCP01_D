import os

html_content = ""
try:
    with open('index.html', 'r') as f:
        html_content = f.read()
except FileNotFoundError:
    print("Fehler: index.html nicht gefunden.")
    html_content = "<h1>Fehler: index.html nicht gefunden.</h1>"
except Exception as e:
    print(f"Fehler beim Lesen der index.html: {e}")
    html_content = f"<h1>Fehler 500: {e}</h1>"


def handler(event, context):
     
    print(f"Anfrage empfangen: {event}")
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/html; charset=utf-8'
        },
        'body': html_content
    }