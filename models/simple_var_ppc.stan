data {
  // Simulation Settings
  int<lower=1> T; // Number of polls
  int<lower=1> P; // Number of parties
  vector[T] N;    // Poll sizes

  // World parameters
  vector[P] sim_alpha;
  matrix[P, P] sim_beta;
  vector<lower=0>[P] sim_sigma;
  simplex[P] x_start;
  real<lower=0> kappa;
}

transformed data {
  int P1 = P - 1; // Because we only estimate P - 1 parties (ALR)
  vector[P] log_start = log(x_start);

  // Transform CLR to ALR
  // Alpha
  vector[P1] alpha;
  for (i in 1:P1) {
    alpha[i] = sim_alpha[i] - sim_alpha[P];
  }

  // Beta
  matrix[P1, P1] beta;
  for (i in 1:P1) {
    for (j in 1:P1) {
      beta[i, j] = sim_beta[i, j] 
                 - sim_beta[i, P] 
                 - sim_beta[P, j] 
                 + sim_beta[P, P];
    }
  }

  // Sigma
  matrix[P1, P1] Sigma_alr;
  real var_ref = square(sim_sigma[P]);
  
  for (i in 1:P1) {
    for (j in 1:P1) {
      Sigma_alr[i, j] = var_ref; 
      if (i == j) {
        Sigma_alr[i, j] += square(sim_sigma[i]);
      }
    }
  }
}

generated quantities {
  // Generated historical data
  array[T] vector[P1] x_raw; 
  array[T] vector[P] phi;
  array[T] vector[P] y_sim;
  
  // Generate latent history
  for (i in 1:P1) {
    x_raw[1][i] = log_start[i] - log_start[P]; 
  }

  // Simulate latent support
  for (t in 2:T) {
    vector[P1] mu = alpha + beta * x_raw[t-1];
    x_raw[t] = multi_normal_rng(mu, Sigma_alr);
  }
  
  // Generate Polls
  for (t in 1:T) {
    vector[P] x_full;
    for (p in 1:P1) x_full[p] = x_raw[t][p];
    x_full[P] = 0;
    
    phi[t] = softmax(x_full);
    real s = N[t] / kappa;
    y_sim[t] = dirichlet_rng(s * phi[t]);
  }

  // CLR - Alpha  
  vector[P] alpha_full = rep_vector(0, P);
  for (k in 1:P1) {
    alpha_full[k] = alpha[k];
  }

  vector[P] alpha_clr = alpha_full - mean(alpha_full);

  // CLR - Beta
  matrix[P, P] beta_full = rep_matrix(0, P, P);  
  for (i in 1:P1) {
    for (j in 1:P1) {
      beta_full[i, j] = beta[i, j];
    }
  }
  real grand_mean = mean(beta_full);
  vector[P] row_means;
  vector[P] col_means;
  
  for (p in 1:P) {
    row_means[p] = mean(beta_full[p, ]);
    col_means[p] = mean(beta_full[ , p]);
  }
  
  matrix[P, P] beta_clr; 
  for (i in 1:P) {
    for (j in 1:P) {
      beta_clr[i, j] = beta_full[i, j] - row_means[i] - col_means[j] + grand_mean;
    }
  }

  // CLR - Sigma
  // Centering Matrix
  matrix[P, P] I = diag_matrix(rep_vector(1, P));
  matrix[P, P] Ones = rep_matrix(1, P, P);
  matrix[P, P] G = I - (1.0/P) * Ones; 

  // ALR Covariance Matrix
  // We assume independent errors
  matrix[P, P] sigma_alr = rep_matrix(0, P, P);
  for(i in 1:P1) {
    for(j in 1:P1) {
      sigma_alr[i, j] = Sigma_alr[i, j];
    }
  }

  // Project to CLR Covariance
  matrix[P, P] sigma_clr_matrix = quad_form(sigma_alr, G');

  // Extract new standard deviations
  vector[P] sigma_clr; 
  for(k in 1:P) {
    sigma_clr[k] = sqrt(fmax(0, sigma_clr_matrix[k, k]));
  }
}
