function BENCHMARK(capacity_benchmark::Array{Int64,2},
                   skus_benchmark::Vector{Int64},
                   start::DataFrame,
                   orders::Int64,
                   max_dependence::Float64,
                   trials::Int64,
                   stagnant::Int64,
                   strategy::Int64,
                   klinkstatus::Int64,
                   abort::Int64,
                   iterations::Int64,
                   show_opt::Bool,
                   cpu_cores::Int64,
                   allowed_gap::Float64,
                   max_nodes::Int64,
                   sig::Float64)
    
    # Start the benchmark of the data set
    ## Create dataframes for the export of the results
    parcels_benchmark = Array{Float64,2}(undef,size(capacity_benchmark,1), 3+size(start,2))  .= 0

    ### Rename the columns appropriately depending on the selected columns in "start"
    parcels_benchmark = DataFrame(parcels_benchmark, [:wareh, 
                                                      :capacity,
                                                      :buffer, 
                                                      :QMKOPT,
                                                      :QMK, 
                                                      :CHI, 
                                                      :CHILOC, 
                                                      :KLINK,
                                                      :KLINKQMK,
                                                      :GP,
                                                      :GS,
                                                      :BS,
                                                      :OPT, 
                                                      :RND])
    names_out = String[]
    start[1,:RND] = 1
    for i = 1:size(start,2)
        if start[1,i] == 0
            names_out = vcat(names_out,names(start)[i])
        end
    end
    parcels_benchmark  = select!(parcels_benchmark, Not(names_out))

    ### Copy the correctly named dataframe for the export dataframes
    time_benchmark    = copy(parcels_benchmark)
    cap_used          = copy(parcels_benchmark)
    parcel_reduction  = copy(parcels_benchmark)
    split_reduction   = copy(parcels_benchmark)
    gap_optimisation  = copy(parcels_benchmark)

    # Iterate all capacity constellations
    for a = 1:size(capacity_benchmark,1)        
        ## Load the capacity of each individual run
        ### Note: It has to be sorted starting with the largest capacity
        capacity = Array{Int64,1}(undef,count(x -> x > 0, capacity_benchmark[a,:]))
        for b = 1:size(capacity,1)
            capacity[b] = capacity_benchmark[a,b]
        end
        print("\ncapacity constellation: ",a," of ",size(capacity_benchmark,1),
            "\ncapacity: ",capacity)
        
        ## Create all possible capacity combinations for the parcel Benchmark
        combination = COMBINEWAREHOUSES(capacity)

        ## Generate artificial random transactions without dependencies if there is no transactional dataset
        if isfile("transactions/transactions_$experiment.csv") == false
            if @isdefined(trans) && size(trans,2) == skus_benchmark[a]
                print("\nReused transactions from previous run.")
            else
                print("\nstarting generation of transactions.")
                time = @elapsed trans = RANDOMTRANS(skus_benchmark[a],orders,ceil(Int64,skus_benchmark[a]/10),
                                                    min_dependence,max_dependence,
                                                    group_link,ind_chance,one_direction,
                                                    multi_relatio)
                print("\ntransactions generated after ", round(time,digits = 3)," seconds.")
            end
        end

        ##  Note the numer of warehouses as well as the capacity in the export dataframes
        parcels_benchmark[a,:wareh] = 
        time_benchmark[a,:wareh] = 
        cap_used[a,:wareh] =
        parcel_reduction[a,:wareh] = 
        split_reduction[a,:wareh] = 
        gap_optimisation[a,:wareh] = size(capacity,1)
        parcels_benchmark[a,:capacity] = 
        time_benchmark[a,:capacity] = 
        cap_used[a,:capacity] = 
        parcel_reduction[a,:capacity] = 
        split_reduction[a,:capacity] =
        gap_optimisation[a,:capacity] = sum(capacity)
        parcels_benchmark[a,:buffer] = 
        time_benchmark[a,:buffer] = 
        cap_used[a,:buffer] = 
        parcel_reduction[a,:buffer] = 
        split_reduction[a,:buffer] =
        gap_optimisation[a,:buffer] = sum(capacity) - size(trans,2)

        #  Split the data into training and test data
        if train_test > 0.00
            cut = round(Int64,size(trans,1) * train_test)
            trans_train = trans[1:cut,:]
            trans_test  = trans[(cut+1):size(trans,1),:]
        else
            trans_train = trans_test = trans
        end
        print("\nNumber of transactions for training ", size(trans_train,1),".") 
        print("\nNumber of transactions for validation ",size(trans_test,1),".")

        #  Start the heuristics and optmisations
        ## Start QMK heuristic to find the optimal solution with the solver CPLEX
        if start[1,:QMKOPT] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:QMKOPT] += @elapsed W,gap_optimisation[a,:QMKOPT] = MQKP(trans_train,capacity,abort,"CPLEX",show_opt,
                                                                                       cpu_cores,allowed_gap,max_nodes,"QMK")
            cap_used[a,:QMKOPT] = sum(W)
            parcels_benchmark[a,:QMKOPT] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n      mqkopt: parcels after optimisation: ", parcels_benchmark[a,:QMKOPT], 
                  " / capacity_used: ", cap_used[a,:QMKOPT], " / time: ",round(time_benchmark[a,:QMKOPT],digits = 3))
            sleep(0.5)
        end

        ## Start QMK heuristic with SBB as solver
        if start[1,:QMK] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:QMK] += @elapsed W,gap_optimisation[a,:QMK] = MQKP(trans_train,capacity,abort,"SBB",show_opt,
                                                                                 cpu_cores,allowed_gap,max_nodes,"QMK")
            cap_used[a,:QMK] = sum(W)
            parcels_benchmark[a,:QMK] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n         mqk: parcels after optimisation: ", parcels_benchmark[a,:QMK], 
                  " / capacity_used: ", cap_used[a,:QMK],  " / time: ", round(time_benchmark[a,:QMK], digits = 3))
            sleep(0.5)
        end

        ## Start CHI square heuristic without local search
        if start[1,:CHI] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:CHI] += @elapsed W = CHISQUAREHEUR(trans_train,capacity,sig,false,show_opt)
            cap_used[a,:CHI] = sum(W)
            parcels_benchmark[a,:CHI] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n         chi: parcels after optimisation: ", parcels_benchmark[a,:CHI], 
                  " / capacity_used: ", cap_used[a,:CHI],  " / time: ",round(time_benchmark[a,:CHI], digits = 3))
            sleep(0.5)
        end

        ## Start CHI square heuristic with local search
        if start[1,:CHILOC] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:CHILOC] += @elapsed W = CHISQUAREHEUR(trans_train,capacity,sig,true,show_opt)
            cap_used[a,:CHILOC] = sum(W)
            parcels_benchmark[a,:CHILOC] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n     chi+loc: parcels after optimisation: ", parcels_benchmark[a,:CHILOC], 
                  " / capacity_used: ", cap_used[a,:CHILOC],  " / time: ",round(time_benchmark[a,:CHILOC], digits = 3))
            sleep(0.5)
        end

        ## Start our reproduction of the  K-LINKS heuristic by
        ## [Zhang, W.-H. Lin, M. Huang and X. Hu (2021)](https://doi.org/10.1016/j.ejor.2019.07.004)
        if  start[1,:KLINK] == 1 && sum(capacity) == size(trans,2)
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:KLINK] += @elapsed W = KLINKS(trans_train,capacity,trials,stagnant,strategy,klinkstatus)
            cap_used[a,:KLINK] = sum(W)
            parcels_benchmark[a,:KLINK] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n     k-links: parcels after optimisation: ", parcels_benchmark[a,:KLINK], 
                  " / capacity_used: ", cap_used[a,:KLINK],  " / time: ",round(time_benchmark[a,:KLINK], digits = 3))
            sleep(0.5)
        end

        ## Start our reproduction of the  K-LINKS optimization with SBB by
        ## [Zhang, W.-H. Lin, M. Huang and X. Hu (2021)](https://doi.org/10.1016/j.ejor.2019.07.004)
        if  start[1,:KLINKQMK] == 1 && sum(capacity) == size(trans,2)
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:KLINKQMK] += @elapsed W, gap_optimisation[a,:KLINKQMK] = MQKP(trans_train,capacity,abort,"SBB",show_opt,
                                                                                        cpu_cores,allowed_gap,max_nodes,"QMK")
            cap_used[a,:KLINKQMK] = sum(W)
            parcels_benchmark[a,:KLINKQMK] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n k-links+mqk: parcels after optimisation: ", parcels_benchmark[a,:KLINKQMK], 
                  " / capacity_used: ", cap_used[a,:KLINKQMK],  " / time: ",round(time_benchmark[a,:KLINKQMK], digits = 3))
            sleep(0.5)
        end

        ## Start our reproduction of the greedy pairs heuristic by
        ## [A. Catalan and M. Fisher (2012)](https://doi.org/10.2139/ssrn.2166687)
        if start[1,:GP] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:GP] += @elapsed W = GREEDYPAIRS(trans_train,capacity)
            cap_used[a,:GP] = sum(W)
            parcels_benchmark[a,:GP] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n          gp: parcels after optimisation: ", parcels_benchmark[a,:GP], 
                  " / capacity_used: ", cap_used[a,:GP],  " / time: ",round(time_benchmark[a,:GP], digits = 3))
            sleep(0.5)
        end

        ## Start our reproduction of the greedy seeds heuristic by
        ## [A. Catalan and M. Fisher (2012)](https://doi.org/10.2139/ssrn.2166687)
        if start[1,:GS] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:GS] += @elapsed W = GREEDYSEEDS(trans_train,capacity)
            cap_used[a,:GS] = sum(W)
            parcels_benchmark[a,:GS] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n          gs: parcels after optimisation: ", parcels_benchmark[a,:GS], 
                  " / capacity_used: ", cap_used[a,:GS],  " / time: ",round(time_benchmark[a,:GS], digits = 3))
            sleep(0.5)
        end

        ## Start our reproduction of the  bestselling heuristic by
        ## [A. Catalan and M. Fisher (2012)](https://doi.org/10.2139/ssrn.2166687)
        if  start[1,:BS] == 1
            sleep(0.5)
            GC.gc()
            time_benchmark[a,:BS] += @elapsed W = BESTSELLING(trans_train,capacity)
            cap_used[a,:BS] = sum(W)
            parcels_benchmark[a,:BS] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n          bs: parcels after optimisation: ", parcels_benchmark[a,:BS], 
                  " / capacity_used: ", cap_used[a,:BS],  " / time: ",round(time_benchmark[a,:BS], digits = 3))
            sleep(0.5)
        end

        ## Start the search for optimal solution with the solver CPLEX
        ## Choose FULLOPTEQ if each SKUs can only be allocated once, else use
        ## FULLOPTUEQ if SKUs can be allocated multiple times
        if start[1,:OPT] == 1
            sleep(0.5)
            GC.gc()
            if sum(capacity) == size(trans,2)
                time_benchmark[a,:OPT] += @elapsed W,gap_optimisation[a,5],popt = FULLOPTEQ(trans_train,capacity,abort,show_opt,
                                                                                            cpu_cores,allowed_gap,max_nodes)
            else
                time_benchmark[a,:OPT] += @elapsed W,gap_optimisation[a,5],popt = FULLOPTUEQ(trans_train,capacity,abort,show_opt,
                                                                                             cpu_cores,allowed_gap,max_nodes)
            end
            cap_used[a,:OPT] = sum(W)
            parcels_benchmark[a,:OPT] = PARCELSSEND(trans_test, W, capacity, combination)
            print("\n         opt: parcels after optimisation: ", parcels_benchmark[a,:OPT], 
                  " / capacity_used: ", cap_used[a,:OPT],  " / time: ",round(time_benchmark[a,:OPT], digits = 3))
            sleep(0.5)
        end

        ## Benchmark the random allocation of SKUs
        sleep(0.5)
        GC.gc()
        time_benchmark[a,:RND] += @elapsed parcels_benchmark[a,:RND] = RANDOMBENCH(trans_test,capacity,iterations,combination)
        print("\n      random: parcels after optimisation: ", parcels_benchmark[a,:RND])
        sleep(0.5)

        ## Calculate number of split deliveries
        split_reduction[a:a,4:end] .= parcels_benchmark[a:a,4:end] .- (size(trans_test,1))
        print("\n\n")

        ## Calculate the improvements of the heuristic compared to a random allocation
        for j = 4:size(parcels_benchmark,2)
            if parcels_benchmark[a,j] > 0
                parcel_reduction[a,j] = 1-(parcels_benchmark[a,j]/parcels_benchmark[a,:RND])
                split_reduction[a,j]  = 1-(split_reduction[a,j]/split_reduction[a,:RND])
            else
                parcel_reduction[a,j] = 0
                split_reduction[a,j] = 0
            end
        end

        # Export the results after each stage
        CSV.write("results/$(experiment)_a_parcels_sent_$dependency.csv",       parcels_benchmark)
        CSV.write("results/$(experiment)_b_duration_$dependency.csv",           time_benchmark)
        CSV.write("results/$(experiment)_c_capacity_used_$dependency.csv",      cap_used)
        CSV.write("results/$(experiment)_d_parcel_reduction_$dependency.csv",   parcel_reduction)
        CSV.write("results/$(experiment)_e_split_reduction_$dependency.csv",    split_reduction)
        CSV.write("results/$(experiment)_f_optimisation_gap_$dependency.csv",   gap_optimisation)
    end
    print("\n### Final Report ###",
          "\nparcels send: \n",parcels_benchmark,
          "\nTime needed: \n",time_benchmark,
          "\nCap used: \n",cap_used,
          "\nParcel Reduction: \n",parcel_reduction,
          "\nSplit Reduction: \n",split_reduction)
    
    return parcels_benchmark::DataFrame, 
           time_benchmark::DataFrame, 
           cap_used::DataFrame, 
           parcel_reduction::DataFrame, 
           split_reduction::DataFrame, 
           gap_optimisation::DataFrame
end