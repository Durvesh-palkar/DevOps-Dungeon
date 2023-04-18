import requests
import os

def handler(event, context):
    
    # Set the URLs to monitor and slack webhook url
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    services = os.environ["ENDPOINTS_TO_MONITOR"].split(',')
    
    # Dict Service<>Status
    status = {}
    isDown = False
    
    # Dig status for all services
    for service in services:
        status[service]=serviceStatus(service)
        print("Status for {} retrieved: {}".format(service,status[service]))
        if status[service]!="200":
            isDown = True
    
    # If atleast one service is donwn or error, send notification
    if isDown:
        print("Alteast one Service is Down, Sending Notification")
        sendSlackNotification(status=status, notifyUrl=slack_webhook_url)


def serviceStatus(endpoint):
    try:
        response = requests.get(url=f"http://{endpoint}", timeout=5)
        # print("--->>",response)
        return str(response.status_code)
    except:
        return "ERR"
    

def sendSlackNotification(status, notifyUrl):
    
    attachments = [{"text": "One or more services unavailable. Alert will repeat every 5 minutes until all services are up."}]
    for service, statusCode in status.items():
        attachment = {
                #"fallback": "{} service status: {}".format(serviceName, status),
                "title": service,
                #"pretext": "{} service status: {}".format(serviceName, status),
                "text": "{} service status: {}".format(service, statusCode),
                #"color": json.loads(message)['body']['type']=="payment_captured"?"#":"#D00000",
                "color":  "#7CD197" if statusCode=="200" else "#D00000",
                "short": True  
        }
        attachments.append(attachment)
    
    #print(attachments)
    
    bodyAttachment = {
        "attachments": attachments
    }
    
    headers = {"Content-Type": "application/json; charset=utf-8"}

    try:
        # send notification to slack
        response = requests.post(notifyUrl, json=bodyAttachment, headers=headers)

        if response.status_code==200:
            print("Notification sent to Slack channel")
    except:
        print("Error occured while sending slack notification.")


# if __name__ == '__main__':
#     handler(None, None)