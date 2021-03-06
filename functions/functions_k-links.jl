function link(j::Int64,
              q::Int64,
              k::Int64,
              g::Int64,
              L::Array{Float64,2},
              X::Array{Int64,2})
    out = 0.0
    if q != j && X[q,g] == 1
        out = L[j,q] * X[j,k] * X[q,g]
    end
    return out::Float64
end

function INL(j::Int64,
            w1::Int64,
            L::Array{Float64,2},
            X::Array{Int64,2})
    out = 0.0
    for q = 1:size(L,1)
        out += link(j::Int64,
                    q::Int64,
                    w1::Int64,
                    w1::Int64,
                    L::Array{Float64,2},
                    X::Array{Int64,2})
    end
    return out::Float64
end

function OUTL(j::Int64,
              w1::Int64,
              w2::Int64,
              L::Array{Float64,2},
              X::Array{Int64,2})
    out = 0.0
    for q = 1:size(L,1)
        out += link(j::Int64,
                    q::Int64,
                    w1::Int64,
                    w2::Int64,
                    L::Array{Float64,2},
                    X::Array{Int64,2})
    end
    return out::Float64
end 

function DL(j::Int64,
            w1::Int64,
            w2::Int64,
            L::Array{Float64,2},
            X::Array{Int64,2})
    OUTL(j,w1,w2,L,X) - INL(j,w1,L,X)
end

function PAYOFF(j::Int64,
                q::Int64,
                w1::Int64,
                w2::Int64,
                L::Array{Float64,2},
                X::Array{Int64,2})
    DL(j,w1,w2,L,X) + DL(q,w2,w1,L,X) - 2*L[j,q]
end

function LINKS(trans::Array{Int64,2},
               ov::Array{Float64,1})
    L = Array{Float64,2}(undef,size(trans,2),size(trans,2)) .= 0
    for j = 1:size(trans,2)
        for q = 1:size(trans,2)
            if j == q
                L[j,q] = 0
            else
                for i = 1:size(trans,1)
                    L[j,q] += ov[i] * trans[i,j] * trans[i,q]
                end
            end
        end
    end
    return L::Array{Float64,2}
end

function LINKADJUST(trans::Array{Int64,2})
    ov = Array{Float64,1}(undef,size(trans,1))
    ov .= 0
    for i = 1:size(trans,1)
        if sum(trans[i,:]) > 1
            ov[i] = sum(trans[i,:])-1/(factorial(big(sum(trans[i,:])))/factorial(2)*factorial(big(sum(trans[i,:])-2)))
        end
    end
    return ov::Array{Float64,1}
end

function LWbest(L::Array{Float64,2})
    LW_best = 0
    for j = 1:size(L,2)
        for q = j+1:size(L,2)
            if j < q
                LW_best += L[j,q]
            end
        end
    end
    return LW_best::Int64
end

function LW(L::Array{Float64,2},
            X::Array{Int64,2})
    out = 0
    for k = 1:(size(X,2))
        for j = 1:size(X,1)
            for q = j+1:size(X,1)
                if j < q
                    out += L[j,q] * X[j,k] * X[q,k]
                end
            end
        end
    end
    return out::Float64
end

function STRATEGY1(X::Array{Int64,2},
                   m::Int64,
                   L::Array{Float64,2},
                   capacity::Array{Int64,1},
                   stop::Int64)
    dl_arr = Array{Float64,3}(undef,size(X,1),size(X,1),size(X,2)) .= 0
    for i in 1:size(X,1)
        if X[i,m] == 1
            for g = 1:size(X,2)
                if sum(X[:,g]) < capacity[g] && m!=g
                    dl_arr[i,m,g] = DL(i,m,g,L,X)
                end
            end
        end
    end
    if findmax(dl_arr)[1] > 0
        X[getindex(findmax(dl_arr)[2],1),getindex(findmax(dl_arr)[2],2)] = 0
        X[getindex(findmax(dl_arr)[2],1),getindex(findmax(dl_arr)[2],3)] = 1
        stop = 0
    end
    return X::Array{Int64,2}
end

function STRATEGY2(X::Array{Int64,2},
                   m::Int64,
                   L::Array{Float64,2},
                   capacity::Array{Int64,1},
                   stop::Int64)
    pay_arr = Array{Float64,4}(undef,size(X,1),size(X,1),size(capacity,1),size(capacity,1)) .= 0
    for i in 1:size(X,1)
        if X[i,m] == 1 
            for j in 1:size(X,1)
                for g = 1:size(X,2)
                    if m != g && X[j,g] == 1
                        pay_arr[i,j,m,g] = PAYOFF(i,j,m,g,L,X)
                    end
                end
            end
        end
    end
    if findmax(pay_arr)[1] > 0
        X[getindex(findmax(pay_arr)[2],1),getindex(findmax(pay_arr)[2],3)] = 0
        X[getindex(findmax(pay_arr)[2],1),getindex(findmax(pay_arr)[2],4)] = 1
        X[getindex(findmax(pay_arr)[2],2),getindex(findmax(pay_arr)[2],4)] = 0
        X[getindex(findmax(pay_arr)[2],2),getindex(findmax(pay_arr)[2],3)] = 1
        stop = 0
    end
    return X::Array{Int64,2}
end