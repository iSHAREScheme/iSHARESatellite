import urllib3, ssl, json, time, smtplib
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
result = None
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
def main():
    http = urllib3.PoolManager(retries=False, cert_reqs='CERT_NONE')
    with open("url.json") as gfile:
        data = json.load(gfile)
    for k in data:
        try:
            r = http.request('GET', data[k],  timeout=10)
#            print(r.status, "Success")
            if r.status != 200:
                mail(r.status, data[k])
#                print("Error")
        except urllib3.exceptions.MaxRetryError :
#            print("Retry Error")
            mail(" network is slow", data[k])
        except urllib3.exceptions.ConnectTimeoutError:
#            print("Connection Error")
            mail(" is down", data[k])
        except urllib3.exceptions.TimeoutError :
            mail(" connection Timeout", data[k])
#            print("timeout")

def mail(reason, url):
        FROM = "<Form_Email_ID>"
        TO = ["<To_Email_ID>"] # must be a list
        SUBJECT = "<Eneter_Email_Subject>"
        TEXT = url+" "+ reason
        message = 'Subject: {}\n\n{}'.format(SUBJECT, TEXT)
        server = smtplib.SMTP("<HOST>")
        server.starttls()
        server.login(FROM,'xcjribgwcmztxbap')
        server.sendmail(FROM, TO, message)
        server.quit()

if __name__ == '__main__':
	main()
