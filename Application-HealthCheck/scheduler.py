import schedule
import time
import datetime
import check

def job():
	check.main()

schedule.every(10).minutes.do(job)


i=0
while 1:
    schedule.run_pending()
    time.sleep(0.001)
