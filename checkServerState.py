import time
import sys

print "Checking server state for server: "+sys.argv[1]
print "Connected to WLS Administration Server? "+connected
while connected!=true:
        java.lang.Thread.sleep(20000)
        try:
                connect(sys.argv[2],sys.argv[3],'t3://tinland11.iamlab.steria:7001')
                print "Connected to WLS Administration Server? "+connected
                domainRuntime()
                cd('/ServerLifeCycleRuntimes/' + sys.argv[1])
                status=get('State')
                print "Server state for server "+sys.argv[1]+" is: "+status
                while status!='RUNNING':
                        java.lang.Thread.sleep(20000)
						print "Wating for server "+sys.argv[1]+" to start up."
						status=get('State')
						print "Server state for server "+sys.argv[1]+" is: "+status
                break
        except:
                print "Something was wrong; server is probably not up."