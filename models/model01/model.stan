data {
  int<lower=0, upper=1> lik;

  int<lower=1> T; // How many days in total there were?
  int<lower=1> P; // How many poll were there?
  int<lower=1> K; // How many parties there are?

  matrix[P, K] y; // Voteshare every poll-day
  array[P] int<lower=1,upper=T> yt; // Poll-days

  row_vector[K] initial_state; // Initial state for the latent variable
}

parameters {
  // Non-centered parametrization
  matrix[T, K] alpha_std;
  
  row_vector[K] mu_raw;
  row_vector<lower=0,upper=1>[K] beta;
  row_vector<lower=0>[K] sigma;

  real<lower=1> phi;
}

transformed parameters {
  // Full latent space
  matrix[T, K] alpha_raw;
  alpha_raw[1] = mu_raw + sigma .* alpha_std[1];
  for (i in 2:T) {
    alpha_raw[i] = mu_raw + beta .* (alpha_raw[i-1] - mu_raw) + sigma .* alpha_std[i];
  }
  
  // Softmax transform
  matrix[T, K + 1] alpha;
  for (i in 1:T) {
    vector[K + 1] alpha_full = append_row(alpha_raw[i]', 0);
    alpha[i] = to_row_vector(softmax(alpha_full));
  }
}

model {
  // Priors
  mu_raw ~ normal(0, 2); // Long-term party support in the latent space
  beta ~ beta(3, 3);       // How much of the shock persists?
  sigma ~ exponential(10); // What is the variability of the support?
  
  // Non-centered sampling
  to_vector(alpha_std) ~ std_normal();

  phi ~ gamma(10, 1);

  // Likelihood
  if (lik == 1) {
    for (i in 1:P) {
      vector[K + 1] y_full;
      y_full[1:K] = to_vector(y[i]);
      y_full[K + 1] = 1 - sum(y[i]);

      int poll_day = yt[i];    
      y_full ~ dirichlet(phi * to_vector(alpha[poll_day]));
    }
  }
}

generated quantities {
   row_vector[K + 1] mu;
   mu[1:K] = mu_raw;
   mu[K + 1] = 0;
   mu = to_row_vector(softmax(to_vector(mu)));
}
