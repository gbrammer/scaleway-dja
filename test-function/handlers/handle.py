"""
./build.sh
python handlers/handle.py

curl localhost:8080

"""

def handle(event, context):
    
    import numpy as np
    
    return {
        "statusCode": 200,
        "body": {
            "message": f"numpy version: {np.__version__}"
        }
    }

if __name__ == "__main__":
    from scaleway_functions_python import local

    local.serve_handler(handle)