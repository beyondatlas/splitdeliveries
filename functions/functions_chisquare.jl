# function used to perform the chi square test of independence upon 
# the coappearance matrix Q
function HYOPTHESISCHI(Q::Array{Int64,2},
                       I::Int64,
                       J::Int64,
                       sig::Float64,
                       sum_cond_sku::Array{Int64,1})
    # Initialise chi square test
    M = convert(Int64,((I^2-I)/2))

    ## Determine the acceptance level of the test
    accept = cquantile(Chisq(1), sig/M)

    ## Create the arrays for the export of the chi-square test
    chi_yy = convert.(Float64,Q)
    norm   = Matrix{Float64}(undef,I,I) .= 0
    dep    = Matrix{Float64}(undef,I,I) .= 0

    @inbounds for i = 2:I
        for j = 1:i-1
            dep[i,j], norm[i,j] = chi_values(chi_yy[i,j], 
                                            sum_cond_sku[i], 
                                            sum_cond_sku[j], 
                                            J, accept)
        end
    end
    dep = dep' + dep
    norm = norm' + norm
    return dep::Array{Float64,2}, 
           norm::Array{Float64,2}
end

function chi_part(a::Float64,b::Float64)
    (a-b)^2/b
end

function chi_part(a::Int64,b::Float64)
    (a-b)^2/b
end

function chi_values(chi_yy::Float64, 
                    sum_cond_sku_i::Int64, 
                    sum_cond_sku_j::Int64, 
                    J::Int64,
                    accept::Float64)
    chi = 0.0
    dep = 0.0
    norm = (sum_cond_sku_i * sum_cond_sku_j)/J
    if chi_yy > norm
        chi_nr = J - sum_cond_sku_i
        chi_nd = J - sum_cond_sku_j
        chi_yn = sum_cond_sku_i - chi_yy
        chi_ny = sum_cond_sku_j - chi_yy
        chi_nn = chi_nd - chi_yn
        ind_yn = (sum_cond_sku_i * chi_nd)/J
        ind_ny = (sum_cond_sku_j * chi_nr)/J
        ind_nn = (chi_nr * chi_nd)/J
        chi += chi_part(chi_yy,norm)
        chi += chi_part(chi_yn,ind_yn)
        chi += chi_part(chi_ny,ind_ny)
        chi += chi_part(chi_nn,ind_nn)
        if chi > accept
            dep = chi_yy - norm
        else
            norm = chi_yy
        end
    end
    return dep, norm
end

# function to calculate the weight of each warehouse. It shows us the density of 
# the independent coappearances in each warehouse if we were to allocate
# all SKUs according to the highest independent coappearances.
function WHWEIGHT(capacity::Array{Int64,1},
                  sum_nor::Array{Float64,1})
    sort_sum_nor = sort!(copy(sum_nor), rev = true)
    sort_sum_nor = vcat(sort_sum_nor,Array{Float64,1}(undef,sum(capacity)-I).=0)
    weight = Array{Float64,1}(undef,size(capacity)) .= 0
    weight[1] = sum(sort_sum_nor[1:capacity[1]])/sum(sort_sum_nor)
    for k = 2:size(capacity,1)
        weight[k] = sum(sort_sum_nor[sum(capacity[1:k-1]):sum(capacity[1:k])])/
                    sum(sort_sum_nor)
    end
    return weight::Array{Float64,1}
end

# function to find the largest warehouse that still has
# space left
function WHSPACE(cap_left::Array{Int64,1},
                 space::Int64)
    k_ind = 0
    for k in 1:size(cap_left,1)
        if cap_left[k] >= space
            k_ind = k
            break
        end
    end
    return k_ind::Int64
end

# function to select the best SKU for an allocation
function SELECTIK(sum_dep::Array{Float64,1},
                  sum_nor::Array{Float64,1},
                  weight::Array{Float64,1},
                  cap_left::Array{Int64,1},
                  X::Array{Bool,2},
                  dep::Array{Float64,2},)
    i       = findmax(sum_nor)[2]
    if sum(X[i,:]) > 0
        alloc = sum(X, dims = 2)
        for j = 1:size(X,1)
            if alloc[j] == 0
                i = j
                break
            end
        end
    end
    k_ind   = WHSPACE(cap_left,1)
    k_max   = findmax(cap_left)[2]
    pot_dep = WHPOTDEP(cap_left,i,X,dep)
    k_dep   = findmax(pot_dep)[2]
    if pot_dep[k_dep] > 0 && k_ind != k_ind
        sum_dep[i] + sum_nor[i] * weight[k_dep] > 
        sum_nor[i] * weight[k_ind]
            k = k_dep
        elseif k_max != k_ind && sum_dep[i] + sum_nor[i] * weight[k_max] >
            sum_nor[i] * weight[k_ind]
                k = k_max
        else
            k = k_ind
    end
    return i::Int64,
           k::Int64
end

# function to check for each warehouse with free space whether 
# SKU i has significant dependencies to other already allocated SKUs
function WHPOTDEP(cap_left::Array{Int64,1},
                  i::Int64,
                  X::Array{Bool,2},
                  dep::Array{Float64,2})
    pot_dep = Array{Float64,1}(undef,size(cap_left,1)) .= 0
    for k in 1:size(cap_left,1)
        if cap_left[k] > 0
            pot_dep[k] = CALCVAL(X,dep,i,k)
        end
    end
    return pot_dep::Array{Float64,1}
end

# function to remove every so far assigned dependent SKU-pair from 
# the coappearance matrix dep to prevent the allocation bias described 
# in our article. 
function REMOVEALLOC(X::Array{Bool,2},
                     cap_left::Array{Int64,1},
                     nor::Array{Float64,2},
                     dep::Array{Float64,2})
    Qs = copy(dep) .= 0
    for a = 1:size(Qs,1)
        for b = 1:size(Qs,1)
            for k = 1:size(cap_left,1)
                if Qs[a,b] > 0
                    if X[a,k] * X[b,k] == 1
                        Qs[a,b] = 0
                    end
                end
            end
        end
    end
    Qs = nor .+ Qs
    return Qs::Array{Float64,2}
end

# function to check for all unallocated SKUs whether they have positive 
# dependencies to the SKUs in the warehouse k the last SKU was allocated 
# to. If so, check whether the dependencies are expected to dominate the 
# independent coapperances. If yes, allocate the corresponding SKUs to 
# the warehouse k.
function ADDDEPENDENT!(X::Array{Bool,2},
                       cap_left::Array{Int64,1},
                       k::Int64,
                       dep::Array{Float64,2},
                       nor::Array{Float64,2},
                       sum_dep::Array{Float64,1},
                       sum_nor::Array{Float64,1})
    add = 1
    while add == 1 && cap_left[k] > 0 && sum(X) < size(X,1)
        add = 0
        pot_dep = Array{Float64,1}(undef,size(X,1)) .= 0
        pot_nor = Array{Float64,1}(undef,size(X,1)) .= 0
        FINDDEP!(X::Array{Bool,2},
                dep::Array{Float64,2},
                nor::Array{Float64,2},
                k::Int64,
                pot_dep::Array{Float64,1},
                pot_nor::Array{Float64,1})
        i = findmax(pot_dep)[2]
        if findmax(pot_dep)[1] > 0
            if pot_dep[i] >= findmax(pot_nor)[1]
                ALLOCATEONE!(X::Array{Bool,2},
                             sum_dep::Array{Float64,1},
                             sum_nor::Array{Float64,1},
                             cap_left::Array{Int64,1},
                             i::Int64,
                             k::Int64)
                add = 1
            end
        end
    end
end

# function to allocate a selcted product to a selected warehouse
function ALLOCATEONE!(X::Array{Bool,2},
                      sum_dep::Array{Float64,1},
                      sum_nor::Array{Float64,1},
                      cap_left::Array{Int64,1},
                      i::Int64,
                      k::Int64)
    if sum(X[i,:]) == 0
        X[i,k] = 1
        sum_dep[i] = 0
        sum_nor[i] = 0
        cap_left[k] -= 1
    else
        error("This product is already allocated!")
    end
end

## check whether all warehouse except the last one are already full. If
## that is the case just allocate the remaining SKUs yet not allocated there.
function FILLLAST!(X::Array{Bool,2},cap_left::Array{Int64,1})
    go = 1
    for i = 1:size(cap_left,1)-1
        if cap_left[i] == 0 && go == 1
            go = 1
        else
            go = 0
        end
    end
    if go == 1
        allocated = sum(X,dims=2)
        for i = 1:length(allocated)
            if allocated[i] == 0
                X[i,size(cap_left,1)] = 1
                cap_left[size(cap_left,1)] -= 1
            end
        end
    end
end

# function to check the dependencies to already allocated SKUs
function FINDDEP!(X::Array{Bool,2},
                  dep::Array{Float64,2},
                  nor::Array{Float64,2},
                  k::Int64,
                  pot_dep::Array{Float64,1},
                  pot_nor::Array{Float64,1})
    allocated = sum(X,dims=2)
    @inbounds @simd for i in 1:size(X,1)
        if allocated[i] == 0
            pot_dep[i] = CALCVAL(X,dep,i,k)
            pot_nor[i] = CALCVAL(X,nor,i,k)
            if pot_dep[i] > 0
                pot_dep[i] += pot_nor[i]
            end
        end
    end
    return pot_dep::Array{Float64,1},
           pot_nor::Array{Float64,1}
end

function CALCVAL(X::Matrix{Bool},T::Matrix{Float64},i::Int64,k::Int64)
    out = 0
    @avxt for y = 1:size(X,1)
        out += X[y,k] * T[y,i]
    end
    return out
end

# function to allocate the SKUs with the highest potential allocation 
# value to each warehouse with leftover storage space until it is full
function FILLUP!(X::Array{Bool,2},
                Q::Array{Float64,2},
                capacity_left::Array{Int64,1})
    for d = 1:size(capacity_left,1)
        while capacity_left[d] > 0
            best_allocation = Array{Float64,1}(undef,size(Q,1)) .= 0
            for i = 1:size(Q,1)
                if X[i,d] == 0
                    best_allocation[i] = CALCVAL(X,Q,i,d)
                end
            end
            if findmax(best_allocation)[1] > 0
                X[findmax(best_allocation)[2],d] = 1
                capacity_left[d] -= 1
            else
                capacity_left[d] = 0
            end
        end
    end
end

# function to apply a pair-wise exchange local search on the allocation
# of the CHI heuristic
function LOCALSEARCHCHI(W::Array{Int64,2},
                        Q::Array{Int64,2})
    coapp_sort = vec(sum(Q,dims = 2))
    coapp_sort = sortperm(coapp_sort,rev=true)
    for trial = 1:3
        improvement = 0
        for k = 1:size(W,2)-1
            @inbounds for i in coapp_sort
                if W[i,k] == 1 && W[i,k+1] == 0
                    for j in coapp_sort
                        if W[j,k+1] == 1 && W[j,k] == 0
                            iteration = POTENTIALCHI!(i,j,k,k+1,W,Q)
                            if iteration > 0
                                improvement += 1
                                break
                            end
                        end
                    end
                end
            end
        end
    end
   return W::Array{Int64,2}
end

function POTENTIALCHI!(i::Int64,
                       j::Int64,
                       k::Int64,
                       g::Int64,
                       X::Array{Int64,2},
                       Q::Array{Int64,2})
    potential = 0
    @avxt for y = 1:size(Q,1)
        potential += (X[y,g] - X[y,k]) * Q[y,i] + (X[y,k] - X[y,g]) * Q[y,j]
    end
    if potential > 0
        impr = 1
        X[i,k] = 0
        X[j,g] = 0
        X[i,g] = 1
        X[j,k] = 1
    else
        impr = 0
    end
    return impr::Int64
end