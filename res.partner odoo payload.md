RES PARTNER

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



RES PARTNER
create_url = f"{ODOO_URL}/web/dataset/call_kw"
create_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "res.partner",
        "method": "create",
        "args": [{
            "name": "Test CUSTOMER OR SELLER",
            "company_type": "person"/"company",
            "seller_type": "meat"/"livestock"/"both",
            "ref": Supabase ID,
            "supplier_rank": 1 (if seller creation),
            "customer_rank": 1(if customer creation),
            "mobile": mobile_number,
            "email": email,
            "state": "pending",
            "street: "ADDRESS",
            "city": city,
            "zip": zip,
        }],
        "kwargs": {},
    }
}
res = requests.post(create_url, json=create_payload, cookies=auth_res['result']['session_id']).json()


read_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "res.partner",
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
        "model": "res.partner",
        "method": "write",
        "args": [[res["result"]], {"list_price": 150.0, "active": False}],
        "kwargs": {},
    }
}
write_res = requests.post(create_url, json=write_payload, cookies=auth_res['result']['session_id']).json()

unlink_payload = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
        "model": "res.partner",
        "method": "unlink",
        "args": [[res["result"]]],
        "kwargs": {},
    }
}
unlink_res = requests.post(create_url, json=unlink_payload, cookies=auth_res['result']['session_id']).json()





