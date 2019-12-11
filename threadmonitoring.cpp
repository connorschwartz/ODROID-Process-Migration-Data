#include <string>
#include <sstream>
#include <vector>
#include <iostream>
#include <fstream>
#include <chrono>
#include <unistd.h> 

std::string removeNewlines(std::string s) {
	using namespace std;
	stringstream ss(s);
	string to;
	string result = "";
	
	while(getline(ss,to,'\n')){
		result = result + to + " ";
	}
	return result.substr(0, result.length() - 1);
}

std::vector<std::string> split(std::string s, char delimiter) {
	using namespace std;
	int last = 0;
	vector<string> v;
	
	for (int i = 0; i < s.length(); i++) {
		if (s.at(i) == delimiter) {
			v.push_back(s.substr(last, i - last));
			last = i + 1;
		}
	}
	v.push_back(s.substr(last, s.length() - last));
	return v;
}

int main(int argc, char *argv[]) {
	using namespace std;
	using namespace std::chrono;
	bool done = false;
	bool children = false;
	// If there are two arguments, we are looking at child processes. Otherwise we are looking at the top-level processes
	string parent;
	if (argc == 3) {
		children = true;
	}
	string s(argv[1]);				// List of all processes
	if (children) parent = argv[2];	// Name of the parent process, if one exists
	
	// Split the given string to get a vector of process names
	string result = removeNewlines(s);
	vector<string> processes = split(result, ' ');
	
	// These arrays will be used to keep track of the previous values of user time and kernel time for each process, as well as time elapsed since last data collection
	int last1[processes.size()];
	int last2[processes.size()];
	long last3[processes.size()];
	for (int i = 0; i < processes.size(); i++) {
		last1[i] = 0;
		last2[i] = 0;
		last3[i] = 0;
	}

	string line;
	string d;
	vector<string> elements;
	vector<string> data;

	int diff1;				// Difference between current and previous user time by the process
	int diff2;				// Difference between current and previous kernel time by the process
	long diff3;				// Time elapsed since last data collection
	while (!done) {
		done = true;
		for (int i = 0; i < processes.size(); i++) {
			// The name of the proc file depends on whether or not this process has a parent
			ifstream myfile;
			if (children) {
				myfile.open("/proc/" + parent + "/task/" + processes[i] + "/stat");
			}
			else {
				myfile.open("/proc/" + processes[i] + "/stat");
			}
			
			if (myfile.peek() == EOF) continue;	// Move on if the proc file is empty
			getline(myfile, line);
			myfile.close();
			elements = split(line, ' ');
			if (elements[0].compare("cpu") == 0) continue;	// Don't track the process named "cpu" - I think this process comes from our monitoring, not from Chromium itself
			done = false;		// If we reach this point, there are still active processes that need data to be collected
			auto time = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
			// Element 13 = total user time clock ticks so far, element 14 = total kernel time clock ticks so far
			diff1 = stoi(elements[13]) - last1[i];
			diff2 = stoi(elements[14]) - last2[i];
			diff3 = time - last3[i];
			// Data points in order: pid, name, timestamp, total user time, total kernel time, change in user time since last collection, change in kernel time since last collection, time elapsed since last collection
			d = elements[0] + "," + elements[1] + "," + to_string(time) + "," + elements[13] + "," + elements[14] + "," + to_string(diff1) + "," + to_string(diff2) + "," + to_string(diff3);
			last1[i] = stoi(elements[13]);
			last2[i] = stoi(elements[14]);
			last3[i] = time;
			data.push_back(d);
		}
	}
	// Write out headers for each piece of data followed by each line of data
	ofstream outfile ("threaddata.csv");
	outfile << "pid,name,timestamp,usertime,kerneltime,utimediff,ktimediff,timechange\n";
	for (int i = 0; i < data.size(); i++) {
		outfile << data[i] << "\n";
	}
	cout << "Process data collection completed" << endl;
	return 0;
}