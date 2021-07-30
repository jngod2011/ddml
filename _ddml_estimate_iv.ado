*** ddml estimation: partial linear IV model

program _ddml_estimate_iv, eclass sortpreserve

	syntax namelist(name=mname) [if] [in] , /// 
								[  ///
								ROBust ///
								show(string) /// dertermines which to post
								clear /// deletes all tilde-variables (to be implemented)
								avplot ///
								debug ///
								* ]

	if ("`show'"=="") {
		local show opt 
	}

	// base sample for estimation - determined by if/in
	marksample touse
	// also exclude obs already excluded by ddml sample
	qui replace `touse' = 0 if `mname'_sample==0

    //mata: `mname'.nameDtilde
    mata: st_local("Yopt",`mname'.nameYopt)
    mata: st_local("Dopt",invtokens(`mname'.nameDopt))
    mata: st_local("Zopt",invtokens(`mname'.nameZopt))

    _ddml_make_varlists, mname(`mname')
    if ("`debug'"!="") {
        return list
    }

    _ddml_allcombos `r(eq)' , putlast(`Yopt' `Dopt' `Zopt') ///
                                                `debug' ///
                                                dpos_end(`r(dpos_end)') ///
                                                zpos_start(`r(zpos_start)') zpos_end(`r(zpos_end)') ///
                                                addprefix("")

	//return list
	local ncombos = r(ncombos)
	local tokenlen = `ncombos'*2 -1
	local ylist `r(ystr)'
	local Dlist `r(dstr)'
	local Zlist `r(zstr)' 

	local j = 1
	forvalues i = 1(2)`tokenlen' {
	    if ("`show'"=="all"|`i'==`tokenlen') {
	    	tokenize `ylist' , parse("-")
	    	local y ``i''
	    	tokenize `Dlist' , parse("-")
	    	local d ``i''
	    	tokenize `Zlist' , parse("-")
	    	local z ``i''
            if (`j'==`ncombos') {
                if "`show'"=="all" di as res "Optimal model: " _c
                local qui qui
            } 
            else {
                local qui
            }
	    	di as res "DML with Y=`y' and D=`d', Z=`z':"
	       	`qui' ivreg2 `y' (`d'=`z') if `touse', nocons `robust' noheader nofooter
	     }
	     local j= `j'+1
	}

	// display
	tempname b
	tempname V 
	mat `b' = e(b)
	mat `V' = e(V)
	matrix colnames `b' = `nameD'
	matrix rownames `b' = `nameY'
 	matrix colnames `V' = `nameD'
	matrix rownames `V' = `nameD'
	local N = e(N)
	ereturn clear
	ereturn post `b' `V', depname(`Yopt') obs(`N') esample(`touse')
	if "`robust'"~="" {
		ereturn local vcetype	robust
	}
	ereturn display

end

/*
mata:

string scalar mat_to_varlist(string matrix inmat)
{
	r = rows(inmat)
	for (i=1;i<=r;i++) {

		if (i==1) {
			str = invtokens(inmat[i,]) 
		}
		else {
			str = str + " | " + invtokens(inmat[i,]) 
		}
	} 
	return(str)
}
end
