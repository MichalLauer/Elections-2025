data {
  int<lower=0, upper=1> lik; // Should likelihood urn?

  int<lower=1> T; // How many days in total there were?
  int<lower=1> P; // How many poll were there?
  int<lower=1> K; // How many parties there are?

  matrix[P, K] y; // Voteshare every poll-day that DO NOT have to sum to 1
  array[P] int<lower=1,upper=T> yt; // Poll-days
  row_vector<lower=1>[P] yn;        //Sample sizes

  row_vector<lower=0, upper=1>[K] initial_state; // Initial state for mu
}

transformed data {
  // Convert initial state to CLR
  real initial_state_residual = 1 - sum(initial_state);
  row_vector[K + 1] initial_state_full = append_col(initial_state, initial_state_residual);
  row_vector[K + 1] initial_state_clr = log(initial_state_full) - mean(log(initial_state_full));

  // Compute full matrix
  matrix[P, K + 1] y_full;
  y_full[1:P, 1:K] = y;
  y_full[1:P, K + 1] = 1.0 - y * rep_vector(1.0, K);
}

parameters {
  row_vector<lower=0>[K + 1] mu_sigma;
  matrix[T, K + 1] mu_std;

  row_vector<lower=0>[K + 1] lambda_sigma;
  matrix[T, K + 1] lambda_std;

  real<lower=0> phi;
}

transformed parameters {
  // Non-centered latent parameter mu
  matrix[T, K + 1] mu;
  mu[1] = initial_state_clr + mu_sigma .* mu_std[1];
  for (i in 2:T) {
    mu[i] = mu[i - 1] + mu_sigma .* mu_std[i];
  }

  // Non-centered latent parameter lambda_raw
  matrix[T, K + 1] lambda_raw;
  lambda_raw[1] = mu[1] + lambda_sigma .* lambda_std[1];
  for (i in 2:T) {
    lambda_raw[i] = mu[i] + lambda_sigma .* lambda_std[i];
  }

  // Unconstrained latent parameter lambda
  matrix[T, K + 1] lambda;
  for (i in 1:T) {
    lambda[i] = softmax(lambda_raw[i]')';
  }

  // Concentration of polls
  row_vector<lower=0>[P] concentration = yn / phi;
}

model {
  // Non-centered distributions
  to_vector(mu_std) ~ std_normal();
  to_vector(lambda_std) ~ std_normal();

  // Priors
  to_vector(mu_sigma) ~ exponential(100);
  to_vector(lambda_sigma) ~ exponential(100);
  phi ~ gamma(1, 1);
  
  // Likelihood is defined for every day with a poll
  if (lik == 1) {
    for (i in 1:P) {
      int poll_day = yt[i];
      y_full[i] ~ dirichlet(lambda[poll_day] * concentration[i]);
    }

  }
}

generated quantities {
  matrix[T, K + 1] y_hat;
  
  // Average concentration
  real avg_concentration = mean(yn) / phi; 

  for (i in 1:T) {
    y_hat[i] = dirichlet_rng(lambda[i]' * avg_concentration)';
  }
}
