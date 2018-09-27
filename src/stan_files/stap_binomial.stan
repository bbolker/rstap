
// General Linear STAP for a binomial outcome
functions {
#include /functions/common_functions.stan
#include /functions/binomial_likelihoods.stan
}
data {
  // declares N, K, Z, Q, zbar 
#include /data/NKZ.stan
  int<lower=0> y[N];         // outcome: number of successes
  int<lower=0> trials[N];    // number of trials
  // declares has_intercept, link, prior_dist, prior_dist_for_intercept  
#include /data/data_glm.stan
  // declares has_weights, weights, has_offset, offset 
#include /data/weights_offset.stan
  int<lower=5,upper=5> family;
  // declares prior_{mean, scale, df}, prior_{mean, scale, df}_for_intercept, prior_scale_{mean, scale, df}_for_aux
#include /data/hyperparameters.stan
  // declares t, p[t], l[t], q, len_theta_L, shape, scale, {len_}concentration, {len_}regularization
#include /data/glmer_stuff.stan
  // declares num_not_zero, w, v, u
#include /data/glmer_stuff2.stan
}
transformed data {
  real aux = not_a_number();
  int<lower=1> V[special_case ? t: 0, N] = make_V(N,special_case ? t:0,v);
#include /tdata/tdata_glm.stan
}
parameters {
    real<upper=(link == 4 ? 0.0 : positive_infinity())> gamma[has_intercept];
  // declares z_beta,z_delta,theta_s,theta_t,X, X_tilde
#include /parameters/parameters_glm.stan
}
transformed parameters {
  // defines beta, b, delta, theta_L
#include /tparameters/tparameters_glm.stan
 if (t > 0 ) {
    if (special_case == 1) {
       int start = 1;
       theta_L = scale .* tau;
       if( t == 1) b = theta_L[1] * z_b;
       else for(i in 1:t) {
         int end = start + l[i] - 1;
         b[start:end] = theta_L[i] * z_b[start:end];
         start = end + 1;
         }
     } else {
         theta_L = make_theta_L(len_theta_L, p, 1.0, tau, scale, zeta, rho, z_T);
         b = make_b(z_b, theta_L, p,l);
     }
   }
}
model {
#include /model/make_eta.stan
  if (t > 0){
#include /model/eta_add_Wb.stan
}
  if (has_intercept == 1 ) {
    if (link != 4) eta = eta + gamma[1];
    else eta = gamma[1] + eta - max(eta);
  }
  else{
#include /model/eta_no_intercept.stan
  }
  // Log-likelihood 
  if (has_weights == 0) {  // unweighted log-likelihoods
    real dummy;  // irrelevant but useful for testing
    dummy = ll_binom_lp(y, trials, eta, link);
  }
  else if (has_weights == 1) 
    target += dot_product(weights, pw_binom(y, trials, eta, link));
#include /model/priors_glm.stan
}
generated quantities {
  real alpha[has_intercept];
  real mean_PPD = 0;
  if (has_intercept == 1) {
    alpha[1] = gamma[1] - dot_product(zbar, delta);
  }
  {
    vector[N] pi;
#include /model/make_eta.stan
    if (t > 0){
#include /model/eta_add_Wb.stan
}
    if (has_intercept == 1) {
      if (link != 4) eta = eta + gamma[1];
      else {
        real shift = max(eta);
        eta = gamma[1] + eta - shift;
        alpha[1] = alpha[1] - shift;
      }
    }
    else {
#include /model/eta_no_intercept.stan
    }
    
    pi = linkinv_binom(eta, link);
    for (n in 1:N) mean_PPD = mean_PPD + binomial_rng(trials[n], pi[n]);
    mean_PPD = mean_PPD / N;
  }
}
