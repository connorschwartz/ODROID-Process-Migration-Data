import sys
import process_json as pj

# Convert the json file to a list of timestamps that can be used better by R
def main():
	jsonFile = sys.argv[1]
	jsonData = pj.read_selenium_data(jsonFile)
	fileName = sys.argv[2]
	events = ["startTimestamp", "navigationStart", "fetchStart", "domainLookupStart",
		"domainLookupEnd", "connectStart", "connectEnd", "secureConnectionStart", 
		"requestStart", "responseStart", "responseEnd", "domLoading", "domInteractive",
		"domContentLoadedEventStart", "domContentLoadedEventEnd", "domComplete",
		"loadEventStart", "loadEventEnd"]
	
	f = open(fileName, 'w')
	for site in jsonData['timestamps']:
		for iteration in jsonData['timestamps'][site]:
			for event in events:
				f.write(str(iteration[event][0]))
				f.write("\n")

if __name__ == "__main__":
    main()