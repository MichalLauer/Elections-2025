data {
    int<lower=1> T; // Number of days between first poll and last poll
    int<lower=1> K; // Number of polls conducted
    int<lower=1> P; // Number of parties
    int<lower=1> C; // Number of pollsters
    
    array[K] simplex[P] y; // Results of K polls for P parties
    vector<lower=1>[K] n;  // What was the poll sample size

    array[K] int<lower=1, upper=T> day; // On what day was which poll
    array[K] int<lower=1, upper=C> c;   // What house did given poll
}

transformed data {

}

parameters {
    // Precision parameters and hyperparameters
    vector[K] kappa;
    vector[C] kappa_mu;
    vector<lower=0>[C] kappa_sigma;
    
    // Underlying support
    matrix[T, P-1] alpha_std;
    vector<lower=0>[P-1] sigma_alpha;
    cholesky_factor_corr[P-1] L_Omega;

    // House effect
    matrix[C-1, P] delta_raw;
}

transformed parameters {
    // Precision calculation
    vector[K] s = n .* exp(kappa); 

    // Define house effect with sum-to-zero constraint (CLR)
    matrix[C, P] delta;
    delta[1:(C - 1), ] = delta_raw;
    for (p in 1:P) {
        delta[C, p] = -sum(delta_raw[ , p]);
    }

    // Simulate state-space walk
    matrix[T, P] alpha;
    matrix[T, P-1] alpha_raw;
    matrix[P-1, P-1] L_Sigma = diag_pre_multiply(sigma_alpha, L_Omega);
    
    alpha_raw[1, ] = alpha_std[1, ] * 1.0; // Prior for start
    for (t in 2:T) {
        alpha_raw[t, ] = alpha_raw[t-1, ] + (L_Sigma * alpha_std[t, ]')';
    }
    
    // Map to CLR matrix (Across Parties)
    alpha[, 1:(P-1)] = alpha_raw;
    for (t in 1:T) {
        alpha[t, P] = -sum(alpha_raw[t, ]);
    }
    
    // Thetas on polling days
    array[K] simplex[P] theta;
    for (k in 1:K) {
        theta[k] = softmax(alpha[day[k], ]' + delta[c[k], ]');
    }

}

model {
    // Precision priors
    kappa ~ normal(kappa_mu[c], kappa_sigma[c]);
    kappa_mu ~ normal(0, 0.2);
    kappa_sigma ~ exponential(2);

    // House priors
    to_vector(delta_raw) ~ normal(0, 0.2);

    // Alpha priors
    sigma_alpha ~ exponential(100);
    L_Omega ~ lkj_corr_cholesky(4);
    to_vector(alpha_std) ~ normal(0, 0.01);

    // Likelihood
    for (k in 1:K) {
        y[k] ~ dirichlet(theta[k] * s[k]);
    }

}

generated quantities {
    // Precision posteriors
    vector[K] kappa_out = exp(kappa);
    vector[C] kappa_mu_out = exp(kappa_mu);
    vector[C] kappa_sigma_out = exp(kappa_sigma);

    // Relationship
    matrix[P-1, P-1] Omega = multiply_lower_tri_self_transpose(L_Omega);

    // PPC
    array[K] vector[P] y_sim;
    for (k in 1:K) {
        y_sim[k] = dirichlet_rng(theta[k] * s[k]);
    }
}
