PRODUCT TEMPLATE

FIRST AUTHENTICATE WITH ODOO
auth_url = f"{ODOO_URL}/web/session/authenticate"
auth_payload = {
    "jsonrpc": "2.0",
    "params": {
        "db": DB,
        "login": USERNAME,
        "password": PASSWORD,
    }
}
auth_res = requests.post(auth_url, json=auth_payload).json()



PRODUCT.TEMPLATE
create_url = f"{ODOO_URL}/web/dataset/call_kw"
create_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "product.template",
        "method": "create",
        "args": [{
            "name": "Test Product",
            "type": "product",
            "list_price": 120.0,
            "meat_type": "meat",  # or "livestock"
            "seller_id": "John Seller",  # from Supabase
            "seller_uid": "SUPABASE_UID_123",  # from Supabase
            "description": "Fresh meat from farm",
            "state": "pending",
        }],
        "kwargs": {},
    }
}

res = requests.post(create_url, json=create_payload, cookies=auth_res['result']['session_id']).json()
product_id = res["result"]

extra_images = ["img1.png", "img2.jpg", "img3.jpg", "img4.jpg"]

for path in extra_images:
    with open(path, "rb") as img:
        img_b64 = base64.b64encode(img.read()).decode("utf-8")

    attach_payload = {
        "jsonrpc": "2.0",
        "method": "call",
        "params": {
            "model": "ir.attachment",
            "method": "create",
            "args": [{
                "name": f"Extra Image {path}",
                "type": "binary",
                "datas": img_b64,
                "res_model": "product.template",
                "res_id": product_id,
                "mimetype": "image/jpeg"
            }],
            "kwargs": {},
        }
    }
    requests.post(create_url, json=attach_payload, cookies=auth_res['result']['session_id'])


read_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "product.template",
        "method": "read",
        "args": [[res["result"]], ["id", "name", "list_price"]],
        "kwargs": {},
    }
}
read_res = requests.post(create_url, json=read_payload, cookies=auth_res['result']['session_id']).json()

write_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "product.template",
        "method": "write",
        "args": [[res["result"]], {"list_price": 150.0,"active": False}, 
        	],
        "kwargs": {},
    }
}
write_res = requests.post(create_url, json=write_payload, cookies=auth_res['result']['session_id']).json()

unlink_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "product.template",
        "method": "unlink",
        "args": [[res["result"]]],
        "kwargs": {},
    }
}
unlink_res = requests.post(create_url, json=unlink_payload, cookies=auth_res['result']['session_id']).json()





