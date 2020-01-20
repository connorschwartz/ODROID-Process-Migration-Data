# plot.py
# Creates a plot of the data from analyze.py
from __future__ import print_function
import matplotlib.pyplot as plt
import numpy as np
import math

import sys,glob
from copy import deepcopy

import analyze
import pmc
import process_json as pj

def get_cmap(n, name='hsv'):
    '''Returns a function that maps each index in 0, 1, ..., n-1 to a distinct
    RGB color; the keyword argument name must be a standard mpl colormap name.'''
    return plt.cm.get_cmap(name, n)

def annotate_ax(ax,xy,desc="Description",offset=(5,5)):
    ax.annotate(desc,
            xy=xy,
            xytext=(xy[0]+offset[0],xy[1]+offset[1]),
            arrowprops=dict(shrink=0.05, headwidth=3,headlength=3,width=0.5))

    def max_point(x,y):
        maxVal = np.amax(y)
    i, = np.where(y == maxVal)
    return (x[i],y[i])

def normalize_array(x):
    x = np.asarray(x)
    s = np.sum(x)
    if s == 0:
        return x
    return x /(np.sum(x))

def stackedBar(sites,govConfigs,loadTypes,coreConfigs,websiteData,outputPrefix):
    width = 0.35
    ind = np.arange(2) # one for energy and one for load time
    for site in sites:
        for gov in govConfigs:
            fig, axs = plt.subplots(3,1, figsize=(8,8))
            for index,config in enumerate(coreConfigs):
                prevMeans = [0,0] # start at the bottom
                #print("config: " + config)
                for loadType in loadTypes:
                    loadTypeData = websiteData[config][gov][site][loadType]
                    means = [np.mean(loadTypeData['loadtime']),
                            np.mean(loadTypeData['energy'])]
                    #print(loadTypeData['loadtime'])
                    #print(normalize_array(loadTypeData['loadtime']))
                    #print("means " + str(means))
                    stds = [np.std(loadTypeData['loadtime']),
                            np.std(loadTypeData['energy'])]
                    axs[index].bar(ind,means,width,bottom=prevMeans)
                    if np.sum(means) != 0:
                        prevMeans = means # no copying required because means becomes a new list
                axs[index].set_title(site + " with configuration " + config)
                axs[index].set_xticks(ind)
                axs[index].set_xticklabels(('Load Time (ms)','Energy (mJ)'))
                axs[index].set_ylabel('Average Load Time (ms) per Phase')
                energyAxis = axs[index].twinx()
                energyAxis.set_ylabel('Average Energy (mJ) per Phase')
            axs[0].legend(loadTypes)

        fig.tight_layout()
        plt.savefig(outputPrefix+site+"-"+gov+"-stackedbar.pdf")
        plt.close()


def scatterPlot(sites,govConfigs,loadTypes,loadTypeMap,coreConfigs,websiteData,outputPrefix,filePrefix):
    symbols=['x','o','*','+','>','<','s','v','X','D','p','H']
    for siteIndex,site in enumerate(sites):
        for gov in govConfigs:
            addLegend = True
            fig, axs = plt.subplots(4,1, figsize=(8,8))
            for eventIndex,loadType in enumerate(loadTypes[0:len(loadTypes)-1]):
                loadTimes = []
                energies = []
                for configIndex,config in enumerate(coreConfigs):
                    loadTypeData = websiteData[config][gov][site][loadType]

                    axs[eventIndex%4].scatter(np.mean(loadTypeData['loadtime']),
                            np.mean(loadTypeData['energy']),
                            label=config,c="black",
                            alpha=0.8,marker=symbols[configIndex])

                    axs[eventIndex%4].set_title(loadTypeMap[loadType])
                axs[eventIndex%4].set_ylabel('Energy (mJ)')
                if eventIndex % 4 == 3:
                    axs[eventIndex%4].set_xlabel('Load Time (ms)')
                if (addLegend):
                    fig.legend(loc=4)
                    addLegend = False

            fig.tight_layout()
            plt.savefig(outputPrefix+filePrefix+site+"-"+gov+"-scatter.pdf")
            plt.close()

def overallScatterPlot(sites,govConfigs,loadTypes,loadTypeMap,coreConfigs,websiteData,outputPrefix,filePrefix,iterations):
    symbols=['x','o','*','+','>','<','s','v','X','D','p','H']
    colors = ['r','g','b','orange','purple','black','yellow','gray']
    for siteIndex,site in enumerate(sites):
        fig, axs = plt.subplots(1,1, figsize=(8,8))
        for govIndex,gov in enumerate(govConfigs):
            loadTimes = []
            energies = []
            for configIndex,config in enumerate(coreConfigs):
                loadTypeData = websiteData[config][gov][site]
                x = np.mean(loadTypeData['loadtime'])
                y = np.mean(loadTypeData['energy'])
                cx = 2 * (np.std(loadTypeData['loadtime']) / math.sqrt(iterations))
                cy = 2 * (np.std(loadTypeData['energy']) / math.sqrt(iterations))

                axs.errorbar(x,y,xerr=cx,yerr=cy,
                        label=config,c= colors[configIndex],
                        alpha=0.75,marker=symbols[configIndex])

            axs.set_title("Energy vs. Load Time")
            axs.set_ylabel('Energy (mJ)')
            axs.set_xlabel('Load Time (ms)')

        handles,labels = axs.get_legend_handles_labels() # only apply a legend to the bottom one
        circles = [plt.Circle((0, 0), 0.2, color=col) for col in colors]
        circleLabels = govConfigs
        display = (0,1,2,3,4,5,6,7) # only display the first few handles
        fig.legend([handle for i,handle in enumerate(handles)]+circles,
                      [label for i,label in enumerate(labels)]+circleLabels)

        #fig.tight_layout()
        plt.savefig(outputPrefix+filePrefix+site+"-overall.pdf")
        plt.close()





def main():
    if len(sys.argv) != 3:
        print("error: needs two args: [filePrefix] [iterations]")
        return
    outputPrefix = "plots/"
    filePrefix = sys.argv[1]
    filePrefix += "-"
    iterations = int(sys.argv[2])

    pmcDir = "powmon-data/"
    jsonDir = "json-data/"

    pmcPrefix = pmcDir + filePrefix
    jsonPrefix = jsonDir + filePrefix
    print(pmcPrefix)
    coreConfigs = []
    #badConfigs = ["0l-0b","1l-4b","2l-4b","1l-2b","1l-0b","2l-0b"] # old code
    #for little in ["0l","1l","2l","4l"]:
    #    for big in ["0b","1b","2b","4b"]:
    #        if (little+"-"+big in badConfigs):
    #            continue
    #        coreConfigs.append(little+"-"+big)
    coreConfigs=["AllSmall","Dynamic","1Big","2Big","3Big","4Big","Default","AllBig"]
    govConfigs = ["ii"]

    #loadTypes = ['navigationStart', 'fetchStart', 'domainLookupStart',
    #                      'domainLookupEnd', 'connectStart', 'connectEnd',
    #                      #'secureConnectionStart',
    #                      'requestStart',
    #                      'responseStart', 'responseEnd', 'domLoading',
    #                      'domInteractive', 'domContentLoadedEventStart',
    #                      'domContentLoadedEventEnd', 'domComplete',
    #                      'loadEventStart', 'loadEventEnd' ]


    loadTypes = ['navigationStart', 'requestStart',
            'domLoading',
            'domComplete',
            'loadEventEnd' ]
    loadTypesEnglish = ['Setup Connection','Download Page','Process Page','Run Dynamic Content']
    loadTypesEnglishMap = dict(zip(loadTypes[0:4],loadTypesEnglish))

    sites = [ 'amazon','bbc','cnn','craigslist','ebay','google','msn','slashdot','twitter','youtube' ]
    counters = [ '0x08','0x19','0x16','0x17' ]

    powmon_sample_period = 100.0 # sample period is 100ms

    # Layout for the data:
    # websiteData[coreConfig][govConfig][siteName][loadTimeType][iteration][energy|loadtime] -> npArray of values
    baseContainer = {'energy':np.zeros((iterations-1,)), 'loadtime': np.zeros((iterations,))}
    byLoadType =    dict(zip(loadTypes,[deepcopy(baseContainer) for loadType in loadTypes]))
    bySite =        dict(zip(sites,[deepcopy(byLoadType) for site in sites]))
    byGov =         dict(zip(govConfigs,[deepcopy(bySite) for config in govConfigs]))
    websiteData =   dict(zip(coreConfigs,[deepcopy(byGov) for config in coreConfigs]))
    
    # Layout for data totals across all phases:
    # websiteData[coreConfig][govConfig][siteName][iteration][energy|loadtime] -> npArray of values
    baseContainer = {'energy':np.zeros((iterations-1,)), 'loadtime': np.zeros((iterations-1,))}
    bySite =        dict(zip(sites,[deepcopy(baseContainer) for site in sites]))
    byGov =         dict(zip(govConfigs,[deepcopy(bySite) for config in govConfigs]))
    totalData =   dict(zip(coreConfigs,[deepcopy(byGov) for config in coreConfigs]))
    
    # Layout for counter totals across all trials and phases:
    # counterData[coreConfig][govConfig][siteName][coreNumber][0x08|0x19|0x1d|0x17] -> npArray of values
    # 0x08 = CPU instructions, 0x19 = bus accesses, 0x16 = level 2 data cache accesses, 0x17 = level 2 data cache refills
    baseContainer = {'0x08':np.zeros((8,)), '0x19': np.zeros((8,)), '0x16': np.zeros((8,)), '0x17': np.zeros((8,))}
    bySite =        dict(zip(sites,[deepcopy(baseContainer) for site in sites]))
    byGov =         dict(zip(govConfigs,[deepcopy(bySite) for config in govConfigs]))
    counterData =   dict(zip(coreConfigs,[deepcopy(byGov) for config in coreConfigs]))

    for coreConfig in coreConfigs: # load/organize the data
        pmcFile = pmcPrefix + coreConfig + "-"
        jsonFilePrefix = jsonPrefix + coreConfig + "-"
        for govConfig in govConfigs:
            pmcFilePrefix = pmcPrefix + coreConfig + "-" +  govConfig + "-"
            jsonFilePrefix = jsonPrefix + coreConfig + "-" + govConfig + "-"

            pmcFiles = glob.glob(pmcFilePrefix+"*") # just use pmc files to get id
            ids = []
            for index,f in enumerate(pmcFiles):
                ids.append(pmcFiles[index].split("-")[-1]) # id is last field
            for fileIndex,fileID in enumerate(ids): # for each pair of data files
                pmcFile = pmcFiles[fileIndex]
                print ("on file " + pmcFile)
                jsonFile = jsonFilePrefix + fileID + ".json" # look at same id'd json file
                print("with file " + jsonFile)

                pmcData = pmc.read_data(pmcFile) # ndarray
                jsonData = pj.read_selenium_data(jsonFile) # dict of mixed types

                threshold = 0.01
                for site in sites:
                    try:
                        for index,loadType in enumerate(loadTypes):
                            for i in range(1,iterations):
                                if (index < len(loadTypes) - 1): # don't calculate pow for the extra 'interval'
                                    loadtime = jsonData['timestamps'][site][i][loadTypes[index+1]][0] - jsonData['timestamps'][site][i][loadType][0]
                                    websiteData[coreConfig][govConfig][site][loadType]['loadtime'][i-1] = loadtime;
                                    totalData[coreConfig][govConfig][site]['loadtime'][i-1] += loadtime

                                    start,end = analyze.timestamp_interval(int(jsonData['timestamps'][site][i][loadType][0]),
                                            int(jsonData['timestamps'][site][i][loadTypes[index+1]][0]),
                                            pmcData['Time_Milliseconds'])
                                    
                                    if (start == end-1 and end < len(pmcData['Power_A7'])): # time interval is lower than our powmon recorded, estimate
                                        scaleFactor = loadtime/powmon_sample_period
                                        minPower = min(pmcData['Power_A7'][start-1],pmcData['Power_A7'][end])
                                        maxPower = max(pmcData['Power_A7'][start-1],pmcData['Power_A7'][end])
                                        energyLittle = (minPower + 0.5*(maxPower-minPower)) * scaleFactor * (pmcData['Time_Milliseconds'][end] - pmcData['Time_Milliseconds'][start])
                                        minPower = min(pmcData['Power_A15'][start-1],pmcData['Power_A15'][end])
                                        maxPower = max(pmcData['Power_A15'][start-1],pmcData['Power_A15'][end])
                                        energyBig = (minPower + 0.5*(maxPower-minPower)) * scaleFactor * (pmcData['Time_Milliseconds'][end] - pmcData['Time_Milliseconds'][start])
                                        energy = energyBig + energyLittle
                                        if energy <= threshold:
                                            print("0 energy calculated from (" + str(minPower) + "0.5*(" + str(maxPower) + "-" + str(minPower) + ")) * " + str(scaleFactor))
                                            print("scaleFactor = " + str(loadtime) + "/" + str(powmon_sample_period))
                                    elif start == end -1: # edge case where data is not available
                                        print("edge case found with loadType" + loadType)
                                        energy = -100
                                    else:
                                        energy =  pmc.calc_energy(pmcData['Power_A7'][start:end], pmcData['Time_Milliseconds'][start:end])
                                        energy += pmc.calc_energy(pmcData['Power_A15'][start:end], pmcData['Time_Milliseconds'][start:end])
                                        if energy <= threshold:
                                            print("0 energy calculated from regular integration")
                                            print(start)
                                            print(end)
                                            print(pmcData['Power_A7'][start:end])
                                            print(pmcData['Power_A15'][start:end])
                                            print(pmcData['Time_Milliseconds'][start:end])
                                    if (start != end): # if we didn't do an approximation
                                        websiteData[coreConfig][govConfig][site][loadType]['energy'][i-1] = energy
                                        totalData[coreConfig][govConfig][site]['energy'][i-1] += energy
                                    else:
                                        websiteData[coreConfig][govConfig][site][loadType]['energy'][i-1] = \
                                                energy*(loadtime/powmon_sample_period)
                                        totalData[coreConfig][govConfig][site]['energy'][i-1] += energy*(loadtime/powmon_sample_period)
                            length = len(pmcData['Core_0_Event_0x08'])
                            for j in range(0,8):
                                for count in counters:
                                    name = 'Core_' + str(j) + '_Event_' + count
                                    counterData[coreConfig][govConfig][site][count][j] = pmcData[name][length - 1] - pmcData[name][0]
                    except KeyError as e:
                        print("asdf")
                    except IndexError as e:
                        print("asdf")
    # Create a csv file that can be used for analysis of power and energy
    s = "plots/" + filePrefix + "core-migration-data.csv"
    f = open(s, 'w')
    f.write("Webpage,Coreconfig,Govconfig,loadTime,energy\n")
    for coreConfig in coreConfigs:
        for govConfig in govConfigs:
            for site in sites:
                for i in range(0,iterations-1):
                    if i == 0:
                        if totalData[coreConfig][govConfig][site]['loadtime'][0] > 3 * totalData[coreConfig][govConfig][site]['loadtime'][1]:
                            totalData[coreConfig][govConfig][site]['loadtime'][0] = totalData[coreConfig][govConfig][site]['loadtime'][1]
                        if totalData[coreConfig][govConfig][site]['energy'][0] > 3 * totalData[coreConfig][govConfig][site]['energy'][1]:
                            totalData[coreConfig][govConfig][site]['energy'][0] = totalData[coreConfig][govConfig][site]['energy'][1]
                    else:
                        if totalData[coreConfig][govConfig][site]['loadtime'][i] > 3 * totalData[coreConfig][govConfig][site]['loadtime'][i-1]:
                            totalData[coreConfig][govConfig][site]['loadtime'][i] = totalData[coreConfig][govConfig][site]['loadtime'][i-1]
                        if totalData[coreConfig][govConfig][site]['energy'][i] > 3 * totalData[coreConfig][govConfig][site]['energy'][i-1]:
                            totalData[coreConfig][govConfig][site]['energy'][i] = totalData[coreConfig][govConfig][site]['energy'][i-1]
                    f.write(site + "," + coreConfig + "," + govConfig + ",")
                    f.write(str(totalData[coreConfig][govConfig][site]['loadtime'][i]))
                    f.write(",")
                    f.write(str(totalData[coreConfig][govConfig][site]['energy'][i]))
                    f.write("\n")
    
    # Create a csv file that can be used to analyze the counters that were collected (cache accesses, bus cycles, etc.
    s = "counters/" + filePrefix + "counter-data.csv"
    f = open(s, 'w')
    f.write("Webpage,Coreconfig,Govconfig,Core,Counter,Value\n")
    for coreConfig in coreConfigs:
        for govConfig in govConfigs:
            for site in sites:
                for i in range(0,8):
                    for count in counters:
                        f.write(site + "," + coreConfig + "," + govConfig + "," + str(i) + "," + count + ",")
                        f.write(str(counterData[coreConfig][govConfig][site][count][i]))
                        f.write("\n")

    # Individual scatter plots for each phase of execution
    scatterPlot(sites,govConfigs,loadTypes,loadTypesEnglishMap,coreConfigs,websiteData,outputPrefix,filePrefix)
    # Overall scatter plots for entire page loads, with error bars
    overallScatterPlot(sites,govConfigs,loadTypes,loadTypesEnglishMap,coreConfigs,totalData,outputPrefix,filePrefix,iterations)
    
    #Old code, doesn't work currently
    #stackedBar(sites,govConfigs,loadTypes,coreConfigs,websiteData,outputPrefix)


# old code
#cmap=get_cmap(100)
#axs[siteIndex%3][siteIndex%4].scatter(x,y,
#label=coreConfig,c="black",
#alpha=0.8,marker=symbols[configIndex])
#fig.legend(loc=4)

if __name__ == "__main__":
    main()
